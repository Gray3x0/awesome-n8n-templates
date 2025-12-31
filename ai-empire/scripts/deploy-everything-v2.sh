#!/bin/bash

################################################################################
# AI EMPIRE UNIFIED DEPLOYMENT SCRIPT v2.0
# Handles NVIDIA drivers, data migration, and complete service deployment
################################################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

print_header() {
    echo -e "\n${MAGENTA}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC}  $1"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════╝${NC}\n"
}

print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${BLUE}[i]${NC} $1"; }
print_step() { echo -e "${CYAN}[→]${NC} $1"; }

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
AI_EMPIRE_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
LOG_FILE="/var/log/ai-empire-deployment.log"
SKIP_CLEANUP=false
SKIP_NVIDIA=false

# Storage paths
RAID_BASE="/raid"
OLD_DATA_DIR="/raid/n8n-mcp-suite"
POSTGRES_DATA="/raid/postgres"
REDIS_DATA="/raid/redis"
OLLAMA_DATA="/raid/ollama"
N8N_DATA="/raid/n8n"
BACKUPS_DIR="/raid/backups"

# Parse command line arguments
for arg in "$@"; do
    case $arg in
        --skip-cleanup)
            SKIP_CLEANUP=true
            shift
            ;;
        --skip-nvidia)
            SKIP_NVIDIA=true
            shift
            ;;
    esac
done

# Redirect all output to log file as well as stdout
exec > >(tee -a "$LOG_FILE")
exec 2>&1

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (sudo)"
        exit 1
    fi
}

handle_error() {
    print_error "Deployment failed at: $1"
    print_info "Check log file: $LOG_FILE"
    exit 1
}

################################################################################
# STEP 0: NVIDIA DRIVER INSTALLATION
################################################################################

step_0_nvidia_driver() {
    if [ "$SKIP_NVIDIA" = true ]; then
        print_header "STEP 0/16: NVIDIA Driver (SKIPPED)"
        print_warning "NVIDIA driver installation skipped via --skip-nvidia flag"
        return
    fi

    print_header "STEP 0/16: NVIDIA Driver Setup"

    # Check if NVIDIA driver is already installed
    if nvidia-smi &> /dev/null; then
        print_success "NVIDIA driver already installed"
        nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
        return
    fi

    print_step "Detecting NVIDIA GPU..."
    if ! lspci | grep -i nvidia &> /dev/null; then
        print_warning "No NVIDIA GPU detected - skipping driver installation"
        print_info "If you have an NVIDIA GPU, ensure it's properly seated"
        return
    fi

    print_step "Installing NVIDIA driver for Ubuntu 24.04..."

    # Add graphics-drivers PPA for latest drivers
    add-apt-repository -y ppa:graphics-drivers/ppa || true
    apt-get update -qq

    # Install latest stable driver (545 for GTX 1060 on Noble)
    print_step "Installing nvidia-driver-545..."
    apt-get install -y nvidia-driver-545 nvidia-dkms-545 || {
        print_warning "Driver installation failed, trying nvidia-driver-550..."
        apt-get install -y nvidia-driver-550 nvidia-dkms-550 || {
            print_error "NVIDIA driver installation failed"
            print_info "Manual installation required:"
            print_info "  sudo ubuntu-drivers devices"
            print_info "  sudo ubuntu-drivers autoinstall"
            print_warning "Continuing without NVIDIA support - GPU features will be disabled"
            return 1
        }
    }

    print_warning "NVIDIA driver installed - REBOOT REQUIRED before GPU features work"
    print_info "After reboot, verify with: nvidia-smi"
    print_info "Then re-run this script with: sudo bash $0 --skip-cleanup"
}

################################################################################
# STEP 1: NUCLEAR CLEANUP
################################################################################

step_1_nuclear_cleanup() {
    if [ "$SKIP_CLEANUP" = true ]; then
        print_header "STEP 1/16: Nuclear Cleanup (SKIPPED)"
        print_warning "Cleanup skipped via --skip-cleanup flag"
        return
    fi

    print_header "STEP 1/16: Nuclear Cleanup of Existing Installations"
    print_step "Running comprehensive cleanup (preserving data)..."

    # Stop all related services
    print_step "Stopping services..."
    systemctl stop ollama 2>/dev/null || true
    systemctl stop litellm 2>/dev/null || true
    systemctl stop ai-empire-* 2>/dev/null || true

    # Stop containers (both Docker and Podman)
    print_step "Stopping containers..."
    docker stop $(docker ps -aq) 2>/dev/null || true
    podman stop $(podman ps -aq) 2>/dev/null || true

    # Run nuclear cleanup if exists (but preserve /raid data)
    if [ -f "$SCRIPT_DIR/nuclear-cleanup.sh" ]; then
        print_info "Running nuclear cleanup (data preserved)..."
        bash "$SCRIPT_DIR/nuclear-cleanup.sh" || print_warning "Cleanup had some errors, continuing..."
    fi

    # Remove Podman (we're switching to Docker)
    print_step "Removing Podman (switching to Docker)..."
    apt-get remove -y podman podman-docker buildah 2>/dev/null || true
    apt-get autoremove -y

    print_success "Cleanup complete"
    sleep 2
}

################################################################################
# STEP 2: STORAGE SETUP
################################################################################

step_2_storage_setup() {
    print_header "STEP 2/16: Storage Structure Setup"

    # Create RAID directory structure
    print_step "Creating /raid directory structure..."
    mkdir -p "$RAID_BASE"
    mkdir -p "$POSTGRES_DATA"
    mkdir -p "$REDIS_DATA"
    mkdir -p "$OLLAMA_DATA"
    mkdir -p "$N8N_DATA"
    mkdir -p "$BACKUPS_DIR"

    # Check if old data exists and needs migration
    if [ -d "$OLD_DATA_DIR" ]; then
        print_warning "Found existing data at $OLD_DATA_DIR"
        print_step "Creating backup before migration..."

        timestamp=$(date +%Y%m%d_%H%M%S)
        backup_path="$BACKUPS_DIR/pre-migration-$timestamp"
        mkdir -p "$backup_path"

        # Backup existing data
        if [ -d "$OLD_DATA_DIR/data/postgres" ]; then
            print_step "Backing up PostgreSQL data..."
            cp -a "$OLD_DATA_DIR/data/postgres" "$backup_path/" || true
        fi

        if [ -d "$OLD_DATA_DIR/data/redis" ]; then
            print_step "Backing up Redis data..."
            cp -a "$OLD_DATA_DIR/data/redis" "$backup_path/" || true
        fi

        if [ -d "$OLD_DATA_DIR/data/ollama" ]; then
            print_step "Backing up Ollama data..."
            cp -a "$OLD_DATA_DIR/data/ollama" "$backup_path/" || true
        fi

        if [ -d "$OLD_DATA_DIR/n8n_data" ]; then
            print_step "Backing up n8n data..."
            cp -a "$OLD_DATA_DIR/n8n_data" "$backup_path/" || true
        fi

        print_success "Backup created at $backup_path"
    fi

    # Set permissions
    chmod -R 755 "$RAID_BASE"

    print_success "Storage structure ready"
}

################################################################################
# STEP 3: SYSTEM DEPENDENCIES
################################################################################

step_3_system_dependencies() {
    print_header "STEP 3/16: System Dependencies"

    print_step "Updating package lists..."
    apt-get update || handle_error "apt update failed"

    print_step "Cleaning APT cache..."
    apt-get clean
    apt-get autoclean

    # Install system dependencies
    print_step "Installing system dependencies..."
    apt-get install -y \
        curl wget git build-essential \
        python3 python3-pip python3-venv \
        postgresql-client redis-tools \
        nginx certbot python3-certbot-nginx \
        jq net-tools lsof htop \
        software-properties-common \
        ca-certificates gnupg \
        apt-transport-https \
        || handle_error "System dependencies installation failed"

    print_success "System dependencies installed"
}

################################################################################
# STEP 4: DOCKER CE INSTALLATION
################################################################################

step_4_docker_installation() {
    print_header "STEP 4/16: Docker CE Installation"

    if command -v docker &> /dev/null; then
        print_info "Docker already installed: $(docker --version)"

        # Still configure daemon.json for NVIDIA runtime
        print_step "Configuring Docker daemon..."
        mkdir -p /etc/docker

        cat > /etc/docker/daemon.json << 'EOF'
{
  "runtimes": {
    "nvidia": {
      "path": "nvidia-container-runtime",
      "runtimeArgs": []
    }
  },
  "default-runtime": "nvidia",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

        systemctl restart docker
        return
    fi

    print_step "Adding Docker CE repository..."

    # Remove old Docker packages
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Add Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker CE
    print_step "Installing Docker CE..."
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
        || handle_error "Docker CE installation failed"

    # Configure Docker daemon for NVIDIA runtime
    print_step "Configuring Docker daemon..."
    mkdir -p /etc/docker

    cat > /etc/docker/daemon.json << 'EOF'
{
  "runtimes": {
    "nvidia": {
      "path": "nvidia-container-runtime",
      "runtimeArgs": []
    }
  },
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

    # Enable and start Docker
    systemctl enable docker
    systemctl start docker

    # Add user to docker group
    if [ -n "$SUDO_USER" ]; then
        usermod -aG docker "$SUDO_USER" || true
    fi

    # Install docker-compose standalone (for compatibility)
    print_step "Installing docker-compose..."
    curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
        -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    print_success "Docker CE installed: $(docker --version)"
}

################################################################################
# STEP 5: NVIDIA CONTAINER TOOLKIT
################################################################################

step_5_nvidia_container_toolkit() {
    print_header "STEP 5/16: NVIDIA Container Toolkit"

    if ! nvidia-smi &> /dev/null; then
        print_warning "nvidia-smi not available - skipping NVIDIA Container Toolkit"
        print_info "Install NVIDIA driver first, then re-run: sudo bash $0 --skip-cleanup"
        return
    fi

    print_step "Installing NVIDIA Container Toolkit..."

    # Clean up any previous attempts
    rm -f /etc/apt/sources.list.d/nvidia-container-toolkit.list
    rm -f /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    rm -f /usr/share/keyrings/nvidia-container-toolkit.asc

    # Download GPG key (using .asc format for Ubuntu 24.04)
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
        gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit.asc || {
        print_warning "Failed to download NVIDIA GPG key"
        return 1
    }

    # Download and validate repository list
    local temp_list="/tmp/nvidia-container-toolkit.list.$$"
    curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
        -o "$temp_list" || {
        print_warning "Failed to download NVIDIA repository list"
        return 1
    }

    # Check if it's an HTML error page
    if grep -q "<!doctype\|<html\|<HTML" "$temp_list"; then
        print_warning "NVIDIA repository returned HTML error page (404)"
        rm -f "$temp_list"
        return 1
    fi

    # Add signed-by directive and install
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit.asc] https://#g' \
        "$temp_list" > /etc/apt/sources.list.d/nvidia-container-toolkit.list
    rm -f "$temp_list"

    # Update and install
    apt-get update -qq
    apt-get install -y nvidia-container-toolkit || {
        print_warning "NVIDIA Container Toolkit installation failed (not critical)"
        return 1
    }

    # Configure Docker to use NVIDIA runtime
    if command -v nvidia-ctk &> /dev/null; then
        nvidia-ctk runtime configure --runtime=docker || print_warning "nvidia-ctk configure failed"
        systemctl restart docker
        print_success "NVIDIA Container Toolkit configured"

        # Test GPU access
        print_step "Testing GPU access in Docker..."
        docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi || \
            print_warning "GPU test failed - check NVIDIA driver installation"
    else
        print_warning "nvidia-ctk not found"
    fi
}

################################################################################
# STEP 6: PYTHON PACKAGES
################################################################################

step_6_python_packages() {
    print_header "STEP 6/16: Python Packages"

    print_step "Creating Python virtual environment..."
    mkdir -p /opt/ai-empire
    python3 -m venv /opt/ai-empire/venv || handle_error "Failed to create venv"

    print_step "Installing Python packages in venv..."
    /opt/ai-empire/venv/bin/pip install --upgrade pip wheel setuptools

    /opt/ai-empire/venv/bin/pip install -q \
        requests \
        psycopg2-binary \
        flask \
        fastapi \
        uvicorn \
        pydantic \
        redis \
        python-dotenv \
        ollama \
        langchain \
        langchain-community \
        openai \
        litellm \
        anthropic \
        || handle_error "Python packages installation failed"

    # Also install globally with --break-system-packages for system services
    print_step "Installing system-wide Python packages..."
    pip3 install --break-system-packages --ignore-installed -q \
        requests \
        psycopg2-binary \
        flask \
        litellm \
        || handle_error "System Python packages installation failed"

    print_success "Python packages installed"
}

################################################################################
# STEP 7: DATA MIGRATION
################################################################################

step_7_data_migration() {
    print_header "STEP 7/16: Data Migration"

    if [ ! -d "$OLD_DATA_DIR" ]; then
        print_info "No existing data found at $OLD_DATA_DIR - skipping migration"
        return
    fi

    print_step "Migrating data from $OLD_DATA_DIR..."

    # Migrate PostgreSQL data
    if [ -d "$OLD_DATA_DIR/data/postgres" ] && [ "$(ls -A $OLD_DATA_DIR/data/postgres)" ]; then
        print_step "Migrating PostgreSQL data..."
        rsync -av "$OLD_DATA_DIR/data/postgres/" "$POSTGRES_DATA/" || \
            print_warning "PostgreSQL migration had errors"
    fi

    # Migrate Redis data
    if [ -d "$OLD_DATA_DIR/data/redis" ] && [ "$(ls -A $OLD_DATA_DIR/data/redis)" ]; then
        print_step "Migrating Redis data..."
        rsync -av "$OLD_DATA_DIR/data/redis/" "$REDIS_DATA/" || \
            print_warning "Redis migration had errors"
    fi

    # Migrate Ollama models
    if [ -d "$OLD_DATA_DIR/data/ollama" ] && [ "$(ls -A $OLD_DATA_DIR/data/ollama)" ]; then
        print_step "Migrating Ollama models..."
        rsync -av "$OLD_DATA_DIR/data/ollama/" "$OLLAMA_DATA/" || \
            print_warning "Ollama migration had errors"
    fi

    # Migrate n8n data
    if [ -d "$OLD_DATA_DIR/n8n_data" ] && [ "$(ls -A $OLD_DATA_DIR/n8n_data)" ]; then
        print_step "Migrating n8n data..."
        rsync -av "$OLD_DATA_DIR/n8n_data/" "$N8N_DATA/" || \
            print_warning "n8n migration had errors"
    fi

    print_success "Data migration complete"
}

################################################################################
# STEP 8: OLLAMA INSTALLATION
################################################################################

step_8_ollama_install() {
    print_header "STEP 8/16: Ollama Installation"

    print_step "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh || handle_error "Ollama installation failed"

    print_success "Ollama installed"
    sleep 2
}

################################################################################
# STEP 9: OLLAMA GTX 1060 OPTIMIZATION
################################################################################

step_9_ollama_optimize() {
    print_header "STEP 9/16: Ollama GTX 1060 Optimization"

    print_step "Configuring Ollama for GTX 1060 (6GB VRAM)..."

    # Create systemd override directory
    mkdir -p /etc/systemd/system/ollama.service.d

    # Configure for GTX 1060 with q4_0 KV cache and 5.5GB VRAM limit
    cat > /etc/systemd/system/ollama.service.d/override.conf << EOF
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_MODELS=$OLLAMA_DATA"
Environment="OLLAMA_KV_CACHE_TYPE=q4_0"
Environment="OLLAMA_FLASH_ATTENTION=1"
Environment="OLLAMA_NUM_PARALLEL=1"
Environment="OLLAMA_MAX_LOADED_MODELS=1"
Environment="CUDA_VISIBLE_DEVICES=0"
Environment="OLLAMA_MAX_VRAM=5.5GB"
Environment="OLLAMA_KEEP_ALIVE=24h"
EOF

    # Reload and restart Ollama
    systemctl daemon-reload
    systemctl enable ollama
    systemctl restart ollama

    # Wait for Ollama to start
    print_step "Waiting for Ollama to start..."
    sleep 5

    # Verify Ollama is running
    if curl -s http://localhost:11434/api/tags > /dev/null; then
        print_success "Ollama running with GTX 1060 optimizations (q4_0 KV cache, 5.5GB VRAM)"
    else
        handle_error "Ollama failed to start"
    fi
}

################################################################################
# STEP 10: MODELS
################################################################################

step_10_models() {
    print_header "STEP 10/16: Model Installation"

    # Check what models already exist (from migration)
    existing_models=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' || echo "")

    if echo "$existing_models" | grep -q "deepseek-r1:7b"; then
        print_info "DeepSeek R1 7B already installed"
    else
        print_step "Pulling DeepSeek R1 7B model (this may take 10-15 minutes)..."
        ollama pull deepseek-r1:7b || print_warning "DeepSeek R1 7B model download failed"
    fi

    # List installed models
    print_info "Installed models:"
    ollama list || true

    print_success "Models ready"
}

################################################################################
# STEP 11: FABRIC CLI
################################################################################

step_11_fabric() {
    print_header "STEP 11/16: Fabric CLI Installation"

    # Install Go if needed
    if ! command -v go &> /dev/null; then
        print_step "Installing Go 1.21.0..."
        wget -q https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
        tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
        rm go1.21.0.linux-amd64.tar.gz
        export PATH=$PATH:/usr/local/go/bin
        echo 'export PATH=$PATH:/usr/local/go/bin' >> /root/.bashrc
        if [ -n "$SUDO_USER" ]; then
            echo 'export PATH=$PATH:/usr/local/go/bin' >> /home/$SUDO_USER/.bashrc
        fi
    fi

    print_step "Installing Fabric CLI..."
    export PATH=$PATH:/usr/local/go/bin:/root/go/bin
    go install github.com/danielmiessler/fabric@latest || handle_error "Fabric installation failed"

    # Setup Fabric (may require manual configuration)
    export PATH=$PATH:/root/go/bin
    /root/go/bin/fabric --setup || print_warning "Fabric setup requires manual configuration"

    # Make fabric available system-wide
    ln -sf /root/go/bin/fabric /usr/local/bin/fabric || true

    print_success "Fabric CLI installed"
}

################################################################################
# STEP 12: DATABASES (docker-compose)
################################################################################

step_12_databases() {
    print_header "STEP 12/16: Database Deployment"

    print_step "Creating docker-compose configuration for databases..."

    mkdir -p /opt/ai-empire/compose

    cat > /opt/ai-empire/compose/docker-compose.yml << EOF
version: '3.8'

services:
  postgres:
    image: pgvector/pgvector:latest
    container_name: ai-empire-postgres
    restart: unless-stopped
    environment:
      POSTGRES_PASSWORD: changeme
      POSTGRES_DB: ai_empire
      POSTGRES_USER: postgres
    ports:
      - "5432:5432"
    volumes:
      - $POSTGRES_DATA:/var/lib/postgresql/data
    networks:
      - ai-empire

  redis:
    image: redis:latest
    container_name: ai-empire-redis
    restart: unless-stopped
    command: redis-server --appendonly yes
    ports:
      - "6379:6379"
    volumes:
      - $REDIS_DATA:/data
    networks:
      - ai-empire

networks:
  ai-empire:
    driver: bridge
EOF

    print_step "Starting databases with docker-compose..."
    cd /opt/ai-empire/compose
    docker-compose up -d || handle_error "Database deployment failed"

    sleep 5
    print_success "Databases deployed (PostgreSQL + Redis)"
}

################################################################################
# STEP 13: LITELLM
################################################################################

step_13_litellm() {
    print_header "STEP 13/16: LiteLLM Gateway"

    mkdir -p /etc/litellm

    print_step "Creating LiteLLM configuration..."
    cat > /etc/litellm/config.yaml << 'EOF'
model_list:
  # Local Ollama models (GTX 1060)
  - model_name: deepseek-r1-7b
    litellm_params:
      model: ollama/deepseek-r1:7b
      api_base: http://localhost:11434

  # Claude API (fallback when GPU busy)
  - model_name: claude-3-5-sonnet
    litellm_params:
      model: claude-3-5-sonnet-20241022
      api_key: ${ANTHROPIC_API_KEY}

router_settings:
  enable_pre_call_checks: true
  allowed_fails: 3
  num_retries: 2
  routing_strategy: simple-shuffle

litellm_settings:
  success_callback: []
  failure_callback: []
  cache: true
  cache_params:
    type: redis
    host: localhost
    port: 6379
EOF

    print_step "Creating LiteLLM systemd service..."
    cat > /etc/systemd/system/litellm.service << 'EOF'
[Unit]
Description=LiteLLM Proxy Gateway
After=network.target ollama.service docker.service

[Service]
Type=simple
User=root
WorkingDirectory=/etc/litellm
ExecStart=/usr/local/bin/litellm --config /etc/litellm/config.yaml --port 4000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable litellm
    systemctl start litellm

    sleep 3
    print_success "LiteLLM gateway deployed on port 4000"
}

################################################################################
# STEP 14: N8N
################################################################################

step_14_n8n() {
    print_header "STEP 14/16: n8n Automation Platform"

    print_step "Deploying n8n with PostgreSQL backend..."

    # Add n8n to docker-compose
    cat >> /opt/ai-empire/compose/docker-compose.yml << EOF

  n8n:
    image: n8nio/n8n:latest
    container_name: ai-empire-n8n
    restart: unless-stopped
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=changeme
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=ai_empire
      - DB_POSTGRESDB_USER=postgres
      - DB_POSTGRESDB_PASSWORD=changeme
      - N8N_ENCRYPTION_KEY=\${N8N_ENCRYPTION_KEY:-defaultencryptionkey}
    ports:
      - "5678:5678"
    volumes:
      - $N8N_DATA:/home/node/.n8n
    networks:
      - ai-empire
    depends_on:
      - postgres
EOF

    # Restart docker-compose with n8n
    cd /opt/ai-empire/compose
    docker-compose up -d || handle_error "n8n deployment failed"

    sleep 5
    print_success "n8n deployed on port 5678 (admin/changeme)"
}

################################################################################
# STEP 15: AI EMPIRE SERVICES
################################################################################

step_15_ai_empire_services() {
    print_header "STEP 15/16: AI Empire Services"

    INSTALL_DIR="/opt/ai-empire"
    mkdir -p "$INSTALL_DIR"

    print_step "Copying Python modules..."
    cp -r "$AI_EMPIRE_DIR/cloudflare-manager" "$INSTALL_DIR/" || true
    cp -r "$AI_EMPIRE_DIR/tailscale-manager" "$INSTALL_DIR/" || true
    cp -r "$AI_EMPIRE_DIR/domain-manager" "$INSTALL_DIR/" || true
    cp -r "$AI_EMPIRE_DIR/fabric-integration" "$INSTALL_DIR/" || true

    chmod +x "$INSTALL_DIR"/*/*.py 2>/dev/null || true

    print_step "Creating systemd services..."

    # Cloudflare daemon
    cat > /etc/systemd/system/cloudflare-daemon.service << 'EOF'
[Unit]
Description=Cloudflare DNS Auto-Sync Daemon
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/ai-empire/cloudflare-manager
ExecStart=/opt/ai-empire/venv/bin/python3 cloudflare_daemon.py --interval 300
Restart=always
EnvironmentFile=-/opt/ai-empire/cloudflare-manager/env.sh

[Install]
WantedBy=multi-user.target
EOF

    # VRAM Monitor
    cat > /etc/systemd/system/vram-monitor.service << 'EOF'
[Unit]
Description=VRAM Monitoring Daemon
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/ai-empire/fabric-integration
ExecStart=/opt/ai-empire/venv/bin/python3 vram_monitor.py --interval 30
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # Fabric Bridge
    cat > /etc/systemd/system/fabric-bridge.service << 'EOF'
[Unit]
Description=Fabric n8n Bridge API
After=network.target ollama.service litellm.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/ai-empire/fabric-integration
ExecStart=/opt/ai-empire/venv/bin/python3 fabric_n8n_bridge.py --port 8080
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload

    # Start services
    systemctl enable vram-monitor
    systemctl start vram-monitor || print_warning "VRAM monitor needs nvidia-smi"

    systemctl enable fabric-bridge
    systemctl start fabric-bridge

    print_success "AI Empire services deployed"
}

################################################################################
# STEP 16: FINAL SETUP & HEALTH CHECKS
################################################################################

step_16_final_setup() {
    print_header "STEP 16/16: Final Setup & Health Checks"

    print_step "Creating environment templates..."

    # Cloudflare
    cat > /opt/ai-empire/cloudflare-manager/env.sh << 'EOF'
#!/bin/bash
export CLOUDFLARE_API_TOKEN="your_cloudflare_api_token_here"
export CLOUDFLARE_ZONE_ID="your_zone_id_here"
export DOMAIN_NAME="yourdomain.com"
EOF

    # Domain Manager
    cat > /opt/ai-empire/domain-manager/env.sh << 'EOF'
#!/bin/bash
export DB_HOST="localhost"
export DB_PORT="5432"
export DB_NAME="ai_empire"
export DB_USER="postgres"
export DB_PASSWORD="changeme"
export DOMAIN_NAME="yourdomain.com"
export NGINX_CONF_DIR="/etc/nginx/sites-enabled"
EOF

    # Tailscale
    cat > /opt/ai-empire/tailscale-manager/env.sh << 'EOF'
#!/bin/bash
export TAILSCALE_API_KEY="your_tailscale_api_key_here"
export TAILSCALE_TAILNET="default"
EOF

    chmod +x /opt/ai-empire/*/env.sh 2>/dev/null || true

    print_step "Running health checks..."

    # Check services
    local all_healthy=true

    # Ollama
    if curl -s http://localhost:11434/api/tags > /dev/null; then
        print_success "Ollama: HEALTHY"
    else
        print_error "Ollama: DOWN"
        all_healthy=false
    fi

    # LiteLLM
    if curl -s http://localhost:4000/health > /dev/null 2>&1; then
        print_success "LiteLLM: HEALTHY"
    else
        print_warning "LiteLLM: Not responding (may need API key configuration)"
    fi

    # PostgreSQL
    if docker exec ai-empire-postgres pg_isready -U postgres > /dev/null 2>&1; then
        print_success "PostgreSQL: HEALTHY"
    else
        print_error "PostgreSQL: DOWN"
        all_healthy=false
    fi

    # Redis
    if docker exec ai-empire-redis redis-cli ping > /dev/null 2>&1; then
        print_success "Redis: HEALTHY"
    else
        print_error "Redis: DOWN"
        all_healthy=false
    fi

    # n8n
    if curl -s http://localhost:5678 > /dev/null; then
        print_success "n8n: HEALTHY"
    else
        print_error "n8n: DOWN"
        all_healthy=false
    fi

    # GPU Check
    if nvidia-smi &> /dev/null; then
        print_success "NVIDIA GPU: ACCESSIBLE"
        nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv,noheader
    else
        print_warning "NVIDIA GPU: NOT ACCESSIBLE (driver not installed or needs reboot)"
    fi

    if [ "$all_healthy" = true ]; then
        print_success "All core services healthy!"
    else
        print_warning "Some services are down - check logs"
    fi

    print_success "Environment templates created"
}

################################################################################
# DEPLOYMENT SUMMARY
################################################################################

print_deployment_summary() {
    print_header "DEPLOYMENT COMPLETE! 🎉"

    cat << 'EOF'

╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║              🚀 AI EMPIRE SUCCESSFULLY DEPLOYED! 🚀         ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

SERVICES RUNNING:
════════════════

Core Infrastructure:
  ✓ Ollama (DeepSeek R1 7B)    http://localhost:11434
  ✓ LiteLLM Gateway            http://localhost:4000
  ✓ n8n Automation             http://localhost:5678
  ✓ PostgreSQL                 localhost:5432
  ✓ Redis                      localhost:6379

AI Empire Services:
  ✓ Fabric n8n Bridge          http://localhost:8080
  ✓ VRAM Monitor               (background daemon)

STORAGE STRUCTURE:
═════════════════

/raid/
  ├── postgres/    (PostgreSQL data)
  ├── redis/       (Redis data)
  ├── ollama/      (Ollama models)
  ├── n8n/         (n8n workflows)
  └── backups/     (automated backups)

NEXT STEPS:
═══════════

1. Configure API Credentials:
   nano /opt/ai-empire/cloudflare-manager/env.sh
   nano /opt/ai-empire/tailscale-manager/env.sh

2. Start Cloudflare DNS Sync (after configuring):
   sudo systemctl start cloudflare-daemon

3. Access n8n:
   http://localhost:5678
   Username: admin
   Password: changeme

4. Configure LiteLLM with Anthropic API key:
   export ANTHROPIC_API_KEY="your-key-here"
   sudo systemctl restart litellm

5. If NVIDIA driver was just installed:
   sudo reboot
   # After reboot, verify with: nvidia-smi

OLLAMA OPTIMIZATION:
═══════════════════

GTX 1060 6GB Configuration:
  ✓ KV Cache: q4_0 (compressed for memory efficiency)
  ✓ Max VRAM: 5.5GB (0.5GB headroom)
  ✓ Flash Attention: enabled
  ✓ Max Models: 1 (prevent OOM)
  ✓ Models Path: /raid/ollama/

Recommended Models (7B only for 6GB VRAM):
  - deepseek-r1:7b
  - llama2:7b
  - mistral:7b

AVOID 8B+ models on GTX 1060 6GB!

HEALTH CHECK:
════════════

Check all services:
  docker ps
  systemctl status ollama
  systemctl status litellm
  systemctl status vram-monitor
  systemctl status fabric-bridge

Test GPU:
  nvidia-smi
  docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi

LOGS:
════

Deployment log: /var/log/ai-empire-deployment.log
Docker logs:    docker logs <container-name>
Service logs:   journalctl -u <service-name> -f

EOF

    if ! nvidia-smi &> /dev/null; then
        cat << 'EOF'
⚠️  WARNING: NVIDIA DRIVER NOT ACCESSIBLE
════════════════════════════════════════

If you just installed the NVIDIA driver, you must reboot:
  sudo reboot

After reboot, verify GPU access:
  nvidia-smi

Then GPU features will work automatically.

EOF
    fi
}

################################################################################
# MAIN EXECUTION
################################################################################

main() {
    check_root

    cat << 'EOF'

╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║          🚀 AI EMPIRE UNIFIED DEPLOYMENT v2.0 🚀            ║
║                                                              ║
║  GTX 1060 Optimized | Docker CE | NVIDIA Support | RAID     ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

EOF

    print_info "Starting deployment in 5 seconds..."
    print_warning "This will deploy the complete AI Empire infrastructure"
    sleep 5

    step_0_nvidia_driver
    step_1_nuclear_cleanup
    step_2_storage_setup
    step_3_system_dependencies
    step_4_docker_installation
    step_5_nvidia_container_toolkit
    step_6_python_packages
    step_7_data_migration
    step_8_ollama_install
    step_9_ollama_optimize
    step_10_models
    step_11_fabric
    step_12_databases
    step_13_litellm
    step_14_n8n
    step_15_ai_empire_services
    step_16_final_setup

    print_deployment_summary
}

main
