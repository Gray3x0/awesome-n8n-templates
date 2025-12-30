#!/bin/bash

################################################################################
# AI Empire - Management CLI
# Complete control interface for all AI Empire services
################################################################################

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${BLUE}[i]${NC} $1"; }

show_usage() {
    cat << 'EOF'
AI Empire Management CLI

USAGE:
  ./manage.sh <command> [args]

SERVICE MANAGEMENT:
  status                    Show status of all services
  restart <service|all>     Restart service(s)
  logs <service>            View service logs
  monitor                   Real-time monitoring dashboard

DOMAIN MANAGEMENT:
  register-service <name> <subdomain> <port>
                           Register new service with domain manager
  dns-sync                 Sync DNS records with Cloudflare
  ssl-renew               Renew SSL certificates

FABRIC OPERATIONS:
  fabric-test <pattern> <text>
                          Test Fabric pattern execution
  fabric-extract <file>   Extract wisdom from file
  vram-status            Show GPU VRAM usage

TAILSCALE:
  tailscale-status       Show Tailscale VPN status
  tailscale-devices      List all Tailscale devices

HEALTH & MONITORING:
  health-check           Check health of all services
  gpu-status             Show detailed GPU information

BACKUPS:
  backup                 Create full system backup
  restore <file>         Restore from backup
  cloudflare-export      Export DNS records

EXAMPLES:
  ./manage.sh status
  ./manage.sh restart ollama
  ./manage.sh register-service api myapp 3000
  ./manage.sh fabric-test summarize "Long article text here"
  ./manage.sh backup

EOF
}

check_service_status() {
    local service=$1
    local port=$2
    local name=$3

    if systemctl is-active --quiet "$service" 2>/dev/null; then
        print_success "$name is running"
        return 0
    elif lsof -i:"$port" > /dev/null 2>&1; then
        print_success "$name is running (non-systemd)"
        return 0
    else
        print_error "$name is NOT running"
        return 1
    fi
}

show_status() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    AI EMPIRE STATUS                          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    echo "CORE SERVICES:"
    check_service_status "ollama" "11434" "Ollama"
    check_service_status "litellm" "4000" "LiteLLM Gateway"

    if docker ps --format '{{.Names}}' | grep -q "ai-empire-n8n"; then
        print_success "n8n Automation"
    else
        print_error "n8n Automation"
    fi

    if docker ps --format '{{.Names}}' | grep -q "ai-empire-postgres"; then
        print_success "PostgreSQL"
    else
        print_error "PostgreSQL"
    fi

    if docker ps --format '{{.Names}}' | grep -q "ai-empire-redis"; then
        print_success "Redis"
    else
        print_error "Redis"
    fi

    echo ""
    echo "AI EMPIRE SERVICES:"
    check_service_status "cloudflare-daemon" "" "Cloudflare DNS Sync"
    check_service_status "vram-monitor" "" "VRAM Monitor"
    check_service_status "fabric-bridge" "8080" "Fabric n8n Bridge"

    echo ""
    echo "GPU STATUS:"
    if command -v nvidia-smi &> /dev/null; then
        nvidia-smi --query-gpu=temperature.gpu,memory.used,memory.total \
            --format=csv,noheader,nounits | while IFS=, read temp used total; do
            used_pct=$((used * 100 / total))
            echo "  Temperature: ${temp}°C | VRAM: ${used}MB/${total}MB (${used_pct}%)"
        done
    else
        print_warning "nvidia-smi not available"
    fi

    echo ""
}

monitor_services() {
    echo "Starting real-time monitoring (Ctrl+C to exit)..."
    echo ""

    while true; do
        clear
        show_status

        echo "RECENT ACTIVITY:"
        echo ""

        # Show latest Ollama request
        if journalctl -u ollama -n 1 --no-pager 2>/dev/null | grep -q "request"; then
            echo "Ollama: $(journalctl -u ollama -n 1 --no-pager | tail -1)"
        fi

        # Show VRAM usage trend
        if [ -f /var/log/vram_monitor.log ]; then
            echo "VRAM: $(tail -1 /var/log/vram_monitor.log)"
        fi

        sleep 5
    done
}

restart_service() {
    local service=$1

    if [ "$service" == "all" ]; then
        print_info "Restarting all services..."
        systemctl restart ollama litellm cloudflare-daemon vram-monitor fabric-bridge
        docker restart ai-empire-n8n ai-empire-postgres ai-empire-redis
        print_success "All services restarted"
    elif [ "$service" == "ollama" ]; then
        systemctl restart ollama
        print_success "Ollama restarted"
    elif [ "$service" == "litellm" ]; then
        systemctl restart litellm
        print_success "LiteLLM restarted"
    elif [ "$service" == "n8n" ]; then
        docker restart ai-empire-n8n
        print_success "n8n restarted"
    else
        systemctl restart "$service"
        print_success "$service restarted"
    fi
}

view_logs() {
    local service=$1

    if [ "$service" == "ollama" ]; then
        journalctl -u ollama -f
    elif [ "$service" == "litellm" ]; then
        journalctl -u litellm -f
    elif [ "$service" == "fabric" ]; then
        journalctl -u fabric-bridge -f
    elif [ "$service" == "n8n" ]; then
        docker logs -f ai-empire-n8n
    elif [ "$service" == "vram" ]; then
        tail -f /var/log/vram_monitor.log
    else
        journalctl -u "$service" -f
    fi
}

register_service() {
    local name=$1
    local subdomain=$2
    local port=$3

    if [ -z "$name" ] || [ -z "$subdomain" ] || [ -z "$port" ]; then
        print_error "Usage: register-service <name> <subdomain> <port>"
        exit 1
    fi

    python3 /opt/ai-empire/domain-manager/domain_manager.py register "$name" "$subdomain" "$port"
    print_success "Service registered. Run 'dns-sync' to update Cloudflare"
}

dns_sync() {
    systemctl restart cloudflare-daemon
    print_success "DNS sync initiated"
}

ssl_renew() {
    certbot renew --nginx
    print_success "SSL certificates renewed"
}

fabric_test() {
    local pattern=$1
    local text=$2

    if [ -z "$pattern" ] || [ -z "$text" ]; then
        print_error "Usage: fabric-test <pattern> <text>"
        exit 1
    fi

    echo "$text" | fabric --pattern "$pattern"
}

fabric_extract() {
    local file=$1

    if [ ! -f "$file" ]; then
        print_error "File not found: $file"
        exit 1
    fi

    cat "$file" | fabric --pattern extract_wisdom
}

vram_status() {
    if command -v nvidia-smi &> /dev/null; then
        nvidia-smi
    else
        print_error "nvidia-smi not found"
    fi
}

tailscale_status() {
    sudo tailscale status
}

tailscale_devices() {
    python3 /opt/ai-empire/tailscale-manager/tailscale_manager.py devices
}

health_check() {
    echo "Running health checks..."
    echo ""

    # Ollama
    if curl -s http://localhost:11434/api/tags > /dev/null; then
        print_success "Ollama API responding"
    else
        print_error "Ollama API not responding"
    fi

    # LiteLLM
    if curl -s http://localhost:4000/health > /dev/null; then
        print_success "LiteLLM API responding"
    else
        print_error "LiteLLM API not responding"
    fi

    # n8n
    if curl -s http://localhost:5678/healthz > /dev/null; then
        print_success "n8n responding"
    else
        print_error "n8n not responding"
    fi

    # Fabric Bridge
    if curl -s http://localhost:8080/health > /dev/null; then
        print_success "Fabric Bridge responding"
    else
        print_error "Fabric Bridge not responding"
    fi

    # PostgreSQL
    if pg_isready -h localhost -p 5432 > /dev/null 2>&1; then
        print_success "PostgreSQL responding"
    else
        print_error "PostgreSQL not responding"
    fi

    # Redis
    if redis-cli ping > /dev/null 2>&1; then
        print_success "Redis responding"
    else
        print_error "Redis not responding"
    fi
}

gpu_status() {
    if command -v nvidia-smi &> /dev/null; then
        nvidia-smi --query-gpu=index,name,driver_version,memory.total,memory.used,memory.free,temperature.gpu,utilization.gpu,utilization.memory \
            --format=csv,noheader
    else
        print_error "nvidia-smi not found"
    fi
}

backup_system() {
    local backup_dir="/opt/ai-empire-backups"
    mkdir -p "$backup_dir"

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$backup_dir/ai-empire-backup-$timestamp.tar.gz"

    print_info "Creating backup: $backup_file"

    tar -czf "$backup_file" \
        /opt/ai-empire \
        /etc/litellm \
        /etc/systemd/system/ollama.service.d \
        /etc/systemd/system/*-daemon.service \
        /etc/nginx/sites-enabled

    docker exec ai-empire-postgres pg_dump -U postgres ai_empire > "$backup_dir/db-$timestamp.sql"

    print_success "Backup created: $backup_file"
}

cloudflare_export() {
    python3 /opt/ai-empire/cloudflare-manager/cloudflare_manager.py export
    print_success "DNS records exported to dns_backup.json"
}

# Main command router
case "$1" in
    status)
        show_status
        ;;
    monitor)
        monitor_services
        ;;
    restart)
        restart_service "$2"
        ;;
    logs)
        view_logs "$2"
        ;;
    register-service)
        register_service "$2" "$3" "$4"
        ;;
    dns-sync)
        dns_sync
        ;;
    ssl-renew)
        ssl_renew
        ;;
    fabric-test)
        fabric_test "$2" "$3"
        ;;
    fabric-extract)
        fabric_extract "$2"
        ;;
    vram-status)
        vram_status
        ;;
    tailscale-status)
        tailscale_status
        ;;
    tailscale-devices)
        tailscale_devices
        ;;
    health-check)
        health_check
        ;;
    gpu-status)
        gpu_status
        ;;
    backup)
        backup_system
        ;;
    cloudflare-export)
        cloudflare_export
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
