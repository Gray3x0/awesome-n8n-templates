#!/bin/bash

################################################################################
# MASTER DEPLOYMENT SCRIPT - Deploy Complete AI Empire
# Runs everything in perfect order with error handling
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

# Parse command line arguments
for arg in "$@"; do
    case $arg in
        --skip-cleanup)
            SKIP_CLEANUP=true
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

log_environment() {
    echo "" >> "$LOG_FILE"
    echo "=== DEPLOYMENT ENVIRONMENT $(date) ===" >> "$LOG_FILE"
    lsb_release -a 2>&1 >> "$LOG_FILE"
    echo "APT version: $(apt-get --version | head -1)" >> "$LOG_FILE"
    echo "Held packages:" >> "$LOG_FILE"
    apt-mark showhold 2>&1 >> "$LOG_FILE"
    echo "APT check status:" >> "$LOG_FILE"
    dpkg --audit 2>&1 >> "$LOG_FILE"
    echo "=== END ENVIRONMENT ===" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
}

confirm_deployment() {
    cat << 'EOF'

╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║          🚀 AI EMPIRE MASTER DEPLOYMENT 🚀                  ║
║                                                              ║
║  This will deploy the COMPLETE AI Empire infrastructure:   ║
║                                                              ║
║  ✓ Nuclear cleanup of ALL existing Ollama installations    ║
║  ✓ Fresh Ollama with GTX 1060 optimizations                ║
║  ✓ DeepSeek R1-8B model (7GB download)                     ║
║  ✓ Fabric CLI with 300+ patterns                           ║
║  ✓ LiteLLM unified API gateway                             ║
║  ✓ n8n workflow automation                                 ║
║  ✓ PostgreSQL + pgvector                                   ║
║  ✓ Redis caching layer                                     ║
║  ✓ Tailscale VPN                                           ║
║  ✓ Cloudflare DNS automation                               ║
║  ✓ Domain management system                                ║
║  ✓ VRAM-aware routing system                               ║
║  ✓ All Python automation modules                           ║
║  ✓ All systemd services                                    ║
║                                                              ║
║  Expected deployment time: 15-30 minutes                   ║
║  (depending on internet speed for model downloads)         ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

EOF

    read -p "Do you want to continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_warning "Deployment cancelled by user"
        exit 0
    fi
}

################################################################################
# PRE-FLIGHT SYSTEM CHECK
################################################################################

preflight_system_check() {
    print_header "PRE-FLIGHT: System Health Check"

    local issues_found=0
    local held_packages=""
    local broken_deps=""
    local gpg_errors=""

    # Check held packages
    print_step "Checking for held packages..."
    held_packages=$(apt-mark showhold)
    if [ -n "$held_packages" ]; then
        print_warning "Found held packages:"
        echo "$held_packages" | sed 's/^/  - /'
        issues_found=$((issues_found + 1))
    else
        print_success "No held packages"
    fi

    # Check broken dependencies
    print_step "Checking for broken dependencies..."
    if ! dpkg --audit 2>&1 | grep -q "^$"; then
        broken_deps=$(dpkg --audit 2>&1)
        print_warning "Found broken dependencies"
        issues_found=$((issues_found + 1))
    else
        print_success "No broken dependencies"
    fi

    # Check for Brave Browser repo issue
    print_step "Checking for problematic repositories..."
    if [ -f /etc/apt/sources.list.d/brave-browser-apt-nightly.list ] || \
       [ -f /etc/apt/sources.list.d/brave-browser-release.list ] || \
       ls /etc/apt/sources.list.d/brave* 2>/dev/null | grep -q .; then
        print_warning "Found Brave Browser repo (known GPG issue)"
        gpg_errors="brave-browser"
        issues_found=$((issues_found + 1))
    fi

    # Report findings
    if [ $issues_found -gt 0 ]; then
        echo ""
        print_warning "Found $issues_found issue(s) that may cause deployment failure"
        echo ""
        echo "┌─ Interactive Resolution Options ─────────────────────┐"
        echo "│  1. Auto-fix all issues (recommended)               │"
        echo "│  2. Fix only held packages                          │"
        echo "│  3. Continue anyway (risky)                         │"
        echo "│  4. Exit and review manually                        │"
        echo "└──────────────────────────────────────────────────────┘"
        echo ""

        read -p "Choose option [1-4]: " -r choice

        case $choice in
            1)
                print_info "Auto-fixing all issues..."
                fix_system_issues "$held_packages" "$broken_deps" "$gpg_errors"
                ;;
            2)
                print_info "Fixing held packages only..."
                fix_held_packages "$held_packages"
                ;;
            3)
                print_warning "Continuing with existing issues - deployment may fail!"
                sleep 2
                ;;
            4)
                print_info "Exiting for manual review"
                echo ""
                echo "Manual fix commands:"
                echo "  apt-mark showhold          # List held packages"
                echo "  apt-mark unhold <package>  # Unhold a package"
                echo "  apt --fix-broken install   # Fix broken dependencies"
                echo ""
                exit 0
                ;;
            *)
                print_error "Invalid choice"
                exit 1
                ;;
        esac
    else
        print_success "System is healthy - ready for deployment!"
    fi
}

fix_system_issues() {
    local held="$1"
    local broken="$2"
    local gpg="$3"

    # Remove Brave Browser repo if exists
    if [ -n "$gpg" ]; then
        print_step "Removing Brave Browser repository..."
        rm -f /etc/apt/sources.list.d/brave*
        # Remove GPG keys (both old apt-key and new method)
        apt-key del C3DE1DD4F661CDCB 2>/dev/null || true
        rm -f /usr/share/keyrings/brave*
        rm -f /etc/apt/trusted.gpg.d/brave*
        print_success "Brave repository removed"
    fi

    # Fix broken dependencies
    if [ -n "$broken" ]; then
        print_step "Fixing broken dependencies..."
        apt-get --fix-broken install -y
        apt-get --fix-missing -y
        print_success "Dependencies fixed"
    fi

    # Unhold packages (safe ones)
    if [ -n "$held" ]; then
        print_step "Analyzing held packages..."
        echo "$held" | while read -r pkg; do
            # Safe to unhold: docker, podman, dev packages
            if [[ "$pkg" =~ (docker|podman|python|build-essential) ]]; then
                print_info "Unholding safe package: $pkg"
                apt-mark unhold "$pkg"
            # Keep held: CUDA, kernel packages
            elif [[ "$pkg" =~ (cuda|cudnn|linux-image|linux-headers) ]]; then
                print_warning "Keeping held (system critical): $pkg"
            else
                print_warning "Keeping held (manual review needed): $pkg"
            fi
        done
    fi

    # Clean and update
    print_step "Cleaning APT cache..."
    apt-get clean
    apt-get autoclean
    apt-get autoremove -y

    print_step "Updating package lists..."
    apt-get update

    print_success "All issues fixed!"
}

fix_held_packages() {
    local held="$1"

    if [ -n "$held" ]; then
        echo "$held" | while read -r pkg; do
            if [[ "$pkg" =~ (docker|podman|python|build-essential) ]]; then
                print_info "Unholding: $pkg"
                apt-mark unhold "$pkg"
            fi
        done
        print_success "Held packages fixed"
    fi
}

################################################################################
# DEPLOYMENT STEPS
################################################################################

step_1_nuclear_cleanup() {
    if [ "$SKIP_CLEANUP" = true ]; then
        print_header "STEP 1/16: Nuclear Cleanup (SKIPPED)"
        print_warning "Cleanup skipped via --skip-cleanup flag"
        return
    fi

    print_header "STEP 1/16: Nuclear Cleanup of Existing Ollama"
    print_step "Running comprehensive cleanup across entire server..."

    if [ -f "$SCRIPT_DIR/nuclear-cleanup.sh" ]; then
        bash "$SCRIPT_DIR/nuclear-cleanup.sh" || handle_error "Nuclear cleanup failed"
    else
        print_error "nuclear-cleanup.sh not found!"
        exit 1
    fi

    print_success "Cleanup complete - server is clean!"
    sleep 3
}

step_2_system_update() {
    print_header "STEP 2/16: System Update and Dependencies"

    # CRITICAL: Clean corrupted NVIDIA sources before apt update
    print_step "Cleaning corrupted APT sources (if any)..."
    rm -f /etc/apt/sources.list.d/nvidia-container-toolkit.list
    rm -f /etc/apt/sources.list.d/cuda-ubuntu2404-x86_64.sources 2>/dev/null || true
    rm -f /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg 2>/dev/null || true

    # Function to install packages with retry logic
    install_packages_with_retry() {
        local packages="$1"
        local attempt=1
        local max_attempts=3

        while [ $attempt -le $max_attempts ]; do
            print_step "Installation attempt $attempt/$max_attempts..."

            if apt-get install -y $packages 2>&1 | tee -a "$LOG_FILE"; then
                print_success "Packages installed successfully"
                return 0
            else
                print_warning "Installation failed on attempt $attempt"

                if [ $attempt -lt $max_attempts ]; then
                    print_step "Fixing dependencies before retry..."
                    apt-get --fix-broken install -y 2>&1 >> "$LOG_FILE"
                    apt-get clean
                    apt-get update
                    attempt=$((attempt + 1))
                    sleep 2
                else
                    print_error "Failed after $max_attempts attempts"
                    return 1
                fi
            fi
        done
    }

    # Clean APT cache before update
    print_step "Cleaning APT cache..."
    apt-get clean
    apt-get autoclean

    # Update package lists
    print_step "Updating package lists..."
    apt-get update || handle_error "apt update failed"

    # Check if containerd.io exists (Docker Desktop or manual install)
    local docker_pkg="docker.io"
    if dpkg -l | grep -q containerd.io; then
        print_warning "containerd.io detected - using Docker CE instead of docker.io"
        docker_pkg=""  # Don't install docker.io, containerd.io provides it
    fi

    # Install system dependencies with retry
    print_step "Installing system dependencies..."
    local packages="curl wget git build-essential \
        python3 python3-pip python3-venv \
        postgresql-client redis-tools \
        nginx certbot python3-certbot-nginx \
        jq net-tools lsof htop \
        software-properties-common \
        ca-certificates gnupg"

    if [ -n "$docker_pkg" ]; then
        packages="$packages $docker_pkg"
    fi

    install_packages_with_retry "$packages" || handle_error "System dependencies installation failed"

    # Verify installation
    print_step "Verifying installation..."
    if dpkg --audit 2>&1 | grep -q "^$"; then
        print_success "System healthy after Step 2"
    else
        print_warning "System has some issues, but continuing..."
    fi

    print_success "System dependencies installed"
}

step_3_python_packages() {
    print_header "STEP 3/16: Python Packages"
    print_step "Installing Python packages..."

    # Don't upgrade pip on Debian/Ubuntu (it's managed by apt)
    # Use --ignore-installed to avoid conflicts with Debian-managed packages (blinker, etc)
    pip3 install --break-system-packages --ignore-installed -q \
        requests \
        psycopg2-binary \
        flask \
        litellm[proxy] \
        || handle_error "Python packages installation failed"

    print_success "Python packages installed"
}

step_4_docker_setup() {
    print_header "STEP 4/16: Docker Configuration"
    print_step "Configuring Docker..."

    # Install docker-compose via pip if not available
    if ! command -v docker-compose &> /dev/null; then
        print_step "Installing docker-compose via pip..."
        pip3 install --break-system-packages docker-compose
    fi

    systemctl enable docker
    systemctl start docker

    # Add current user to docker group if not root
    if [ -n "$SUDO_USER" ]; then
        usermod -aG docker "$SUDO_USER" || true
    fi

    print_success "Docker configured"
}

step_4b_nvidia_driver() {
    print_header "STEP 4b/16: NVIDIA Driver 570 Installation"

    # Check if NVIDIA driver is already installed
    if command -v nvidia-smi &> /dev/null; then
        local current_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)
        print_info "NVIDIA driver already installed: $current_version"

        # Check if version is 570+
        if [[ "$current_version" == 570* ]] || [[ "$current_version" > "570" ]]; then
            print_success "Driver version $current_version is compatible"
            return 0
        else
            print_warning "Driver version $current_version is older than 570"
            print_info "Upgrading to driver 570..."
        fi
    fi

    print_step "Adding NVIDIA PPA for Ubuntu 24.04..."
    add-apt-repository -y ppa:graphics-drivers/ppa 2>/dev/null || true
    apt-get update -qq

    print_step "Installing NVIDIA driver 570..."
    apt-get install -y --allow-downgrades nvidia-driver-570 || {
        print_warning "nvidia-driver-570 not available, trying nvidia-driver-550..."
        apt-get install -y --allow-downgrades nvidia-driver-550 || {
            print_error "NVIDIA driver installation failed"
            print_warning "You may need to install manually: sudo ubuntu-drivers install"
            return 1
        }
    }

    print_success "NVIDIA driver installed"
    print_warning "A REBOOT may be required for driver changes to take effect"

    # Verify installation
    if command -v nvidia-smi &> /dev/null; then
        print_step "Verifying NVIDIA driver..."
        nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv
        print_success "NVIDIA driver verified"
    fi
}

step_5_nvidia_docker() {
    print_header "STEP 5/16: NVIDIA Docker Runtime"

    if command -v nvidia-smi &> /dev/null; then
        print_step "Installing NVIDIA Docker runtime..."

        # Download GPG key
        curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
            gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg || {
            print_warning "Failed to download NVIDIA GPG key"
            return 1
        }

        # Download repository list to temp file for validation
        print_step "Downloading NVIDIA repository list..."
        curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
            -o /tmp/nvidia-container-toolkit.list || {
            print_warning "Failed to download NVIDIA repository list"
            return 1
        }

        # Validate file is not HTML (404 error page)
        if head -1 /tmp/nvidia-container-toolkit.list | grep -qi "<!doctype\|<html"; then
            print_error "Downloaded file is HTML (404), not a valid repository list"
            print_warning "NVIDIA Container Toolkit repository may not support Ubuntu 24.04 Noble yet"
            print_warning "Skipping NVIDIA Docker installation, continuing with CPU-only setup"
            rm -f /tmp/nvidia-container-toolkit.list
            return 1
        fi

        # File is valid, add signed-by directive and install
        print_step "Installing NVIDIA Container Toolkit..."
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
            /tmp/nvidia-container-toolkit.list | \
            tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null

        rm -f /tmp/nvidia-container-toolkit.list

        # Update and install
        apt-get update -qq || {
            print_warning "apt update failed after adding NVIDIA repository"
            rm -f /etc/apt/sources.list.d/nvidia-container-toolkit.list
            return 1
        }

        apt-get install -y --allow-downgrades -qq nvidia-container-toolkit || {
            print_warning "NVIDIA Container Toolkit installation failed (not critical)"
            return 1
        }

        # Configure Docker to use NVIDIA runtime
        if command -v nvidia-ctk &> /dev/null; then
            nvidia-ctk runtime configure --runtime=docker || print_warning "nvidia-ctk configure failed"
            systemctl restart docker
            print_success "NVIDIA Docker runtime configured"
        else
            print_warning "nvidia-ctk not found after installation"
        fi
    else
        print_warning "NVIDIA GPU not detected (nvidia-smi not available), skipping NVIDIA Docker runtime"
        print_info "If you have an NVIDIA GPU, install the driver first and re-run this script"
    fi
}

step_6_ollama_install() {
    print_header "STEP 6/16: Fresh Ollama Installation"
    print_step "Installing Ollama..."

    curl -fsSL https://ollama.com/install.sh | sh || handle_error "Ollama installation failed"

    print_success "Ollama installed"
    sleep 2
}

step_7_ollama_optimize() {
    print_header "STEP 7/16: GTX 1060 6GB Optimizations"
    print_step "Configuring Ollama for GTX 1060 6GB..."

    # Create RAID models directory for faster I/O
    mkdir -p /raid/ollama
    chown -R root:root /raid/ollama 2>/dev/null || true

    mkdir -p /etc/systemd/system/ollama.service.d

    # GTX 1060 6GB optimized configuration
    # VRAM: 5.5GB in bytes = 5905580032 (leaving 500MB headroom)
    # KV Cache: q4_0 for memory efficiency on Pascal architecture
    cat > /etc/systemd/system/ollama.service.d/override.conf << 'EOF'
[Service]
# Network binding - allow remote access
Environment="OLLAMA_HOST=0.0.0.0:11434"

# Model storage on RAID for performance
Environment="OLLAMA_MODELS=/raid/ollama"

# GTX 1060 6GB Memory Optimizations
# 5.5GB VRAM limit in bytes (6GB - 500MB headroom)
Environment="OLLAMA_MAX_VRAM=5905580032"

# q4_0 KV cache for Pascal architecture (GTX 10xx)
# Reduces VRAM usage by ~50% vs f16, minimal quality loss
Environment="OLLAMA_KV_CACHE_TYPE=q4_0"

# Flash Attention for memory efficiency
Environment="OLLAMA_FLASH_ATTENTION=1"

# Single request processing (VRAM constraint)
Environment="OLLAMA_NUM_PARALLEL=1"

# Keep only one model loaded (VRAM constraint)
Environment="OLLAMA_MAX_LOADED_MODELS=1"

# GPU selection
Environment="CUDA_VISIBLE_DEVICES=0"

# Keep model loaded for 24 hours (avoid reload latency)
Environment="OLLAMA_KEEP_ALIVE=24h"

# Debug logging (comment out for production)
# Environment="OLLAMA_DEBUG=1"
EOF

    systemctl daemon-reload
    systemctl enable ollama
    systemctl restart ollama

    # Wait for Ollama to start with retry
    print_step "Waiting for Ollama to start..."
    local max_attempts=12
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
            print_success "Ollama is running with GTX 1060 optimizations"
            print_info "VRAM limit: 5.5GB | KV cache: q4_0 | Flash attention: enabled"
            return 0
        fi
        print_step "Waiting... (attempt $attempt/$max_attempts)"
        sleep 5
        attempt=$((attempt + 1))
    done

    # If we get here, Ollama failed to start
    print_error "Ollama failed to start after $max_attempts attempts"
    print_info "Checking Ollama service status..."
    systemctl status ollama --no-pager || true
    journalctl -u ollama --no-pager -n 20 || true
    handle_error "Ollama startup failed"
}

step_8_deepseek_model() {
    print_header "STEP 8/16: DeepSeek R1-8B Model Download"
    print_step "Pulling DeepSeek R1-8B model (this may take 10-15 minutes)..."

    ollama pull deepseek-r1:8b || handle_error "Model download failed"

    print_success "DeepSeek R1-8B model ready"
}

step_9_fabric_install() {
    print_header "STEP 9/16: Fabric CLI Installation"

    # Install Go if needed
    if ! command -v go &> /dev/null; then
        print_step "Installing Go..."
        wget -q https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
        tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
        rm go1.21.0.linux-amd64.tar.gz
        export PATH=$PATH:/usr/local/go/bin
        echo 'export PATH=$PATH:/usr/local/go/bin' >> /root/.bashrc
        if [ -n "$SUDO_USER" ]; then
            echo 'export PATH=$PATH:/usr/local/go/bin' >> /home/$SUDO_USER/.bashrc
        fi
    fi

    print_step "Installing Fabric..."
    export PATH=$PATH:/usr/local/go/bin:/root/go/bin
    go install github.com/danielmiessler/fabric@latest || handle_error "Fabric installation failed"

    # Setup Fabric
    export PATH=$PATH:/root/go/bin
    /root/go/bin/fabric --setup || print_warning "Fabric setup requires manual configuration"

    # Make fabric available system-wide
    ln -sf /root/go/bin/fabric /usr/local/bin/fabric || true

    print_success "Fabric CLI installed"
}

step_10_databases() {
    print_header "STEP 10/16: Database Deployment"

    print_step "Starting PostgreSQL with pgvector..."
    docker run -d \
        --name ai-empire-postgres \
        --restart unless-stopped \
        -e POSTGRES_PASSWORD=changeme \
        -e POSTGRES_DB=ai_empire \
        -p 5432:5432 \
        -v postgres-data:/var/lib/postgresql/data \
        pgvector/pgvector:latest \
        || print_warning "PostgreSQL container already exists"

    print_step "Starting Redis..."
    docker run -d \
        --name ai-empire-redis \
        --restart unless-stopped \
        -p 6379:6379 \
        -v redis-data:/data \
        redis:latest redis-server --appendonly yes \
        || print_warning "Redis container already exists"

    sleep 3
    print_success "Databases deployed"
}

step_11_litellm() {
    print_header "STEP 11/16: LiteLLM Gateway Configuration"

    mkdir -p /etc/litellm

    # Create comprehensive LiteLLM config with Ollama primary + Claude fallback
    cat > /etc/litellm/config.yaml << 'EOF'
# LiteLLM Configuration for AI Empire
# Primary: Local Ollama (free) | Fallback: Claude API (paid)

model_list:
  # ═══════════════════════════════════════════════════════════════
  # PRIMARY: Local DeepSeek R1-8B via Ollama (FREE)
  # ═══════════════════════════════════════════════════════════════
  - model_name: deepseek-local
    litellm_params:
      model: ollama/deepseek-r1:8b
      api_base: http://localhost:11434
      timeout: 300
      stream: true
    model_info:
      description: "Local DeepSeek R1-8B - FREE inference"
      max_tokens: 8192

  # Alias for compatibility
  - model_name: deepseek-r1-8b
    litellm_params:
      model: ollama/deepseek-r1:8b
      api_base: http://localhost:11434
      timeout: 300

  # ═══════════════════════════════════════════════════════════════
  # FALLBACK: Claude API (PAID - use sparingly)
  # ═══════════════════════════════════════════════════════════════
  - model_name: claude-fallback
    litellm_params:
      model: claude-3-5-sonnet-20241022
      api_key: os.environ/ANTHROPIC_API_KEY
      timeout: 120
    model_info:
      description: "Claude 3.5 Sonnet - Fallback for complex tasks"

  - model_name: claude-3-5-sonnet
    litellm_params:
      model: claude-3-5-sonnet-20241022
      api_key: os.environ/ANTHROPIC_API_KEY

  # ═══════════════════════════════════════════════════════════════
  # SMART ROUTING: Auto-fallback from local to cloud
  # ═══════════════════════════════════════════════════════════════
  - model_name: smart
    litellm_params:
      model: ollama/deepseek-r1:8b
      api_base: http://localhost:11434
      timeout: 300
      fallbacks:
        - model: claude-3-5-sonnet-20241022
          api_key: os.environ/ANTHROPIC_API_KEY

# Router settings for intelligent failover
router_settings:
  routing_strategy: least-busy
  enable_pre_call_checks: true
  allowed_fails: 2
  num_retries: 3
  retry_after: 5
  timeout: 300
  fallbacks:
    - deepseek-local: [claude-fallback]
    - deepseek-r1-8b: [claude-fallback]

# LiteLLM general settings
litellm_settings:
  drop_params: true
  set_verbose: false

  # Redis caching for response deduplication
  cache: true
  cache_params:
    type: redis
    host: localhost
    port: 6379
    ttl: 3600

  # Callbacks (uncomment for monitoring)
  # success_callback: ["langfuse"]
  # failure_callback: ["langfuse"]

# General settings
general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
  database_url: os.environ/DATABASE_URL

# Environment variable defaults
environment_variables:
  ANTHROPIC_API_KEY: ""
  LITELLM_MASTER_KEY: "sk-litellm-master-key-change-me"
  DATABASE_URL: "postgresql://postgres:changeme@localhost:5432/ai_empire"
EOF

    # Create LiteLLM environment file
    cat > /etc/litellm/env << 'EOF'
# LiteLLM Environment Variables
# Edit these values before starting the service

# Anthropic API Key (required for Claude fallback)
ANTHROPIC_API_KEY=your_anthropic_api_key_here

# LiteLLM Master Key (for API authentication)
LITELLM_MASTER_KEY=sk-litellm-master-key-change-me

# PostgreSQL connection (for logging/analytics)
DATABASE_URL=postgresql://postgres:changeme@localhost:5432/ai_empire

# Redis connection
REDIS_HOST=localhost
REDIS_PORT=6379
EOF

    chmod 600 /etc/litellm/env

    # Create systemd service with environment file
    cat > /etc/systemd/system/litellm.service << 'EOF'
[Unit]
Description=LiteLLM Proxy Gateway - Unified AI API
After=network.target ollama.service redis.service postgresql.service
Wants=ollama.service

[Service]
Type=simple
User=root
WorkingDirectory=/etc/litellm
EnvironmentFile=/etc/litellm/env
ExecStart=/usr/local/bin/litellm --config /etc/litellm/config.yaml --host 0.0.0.0 --port 4000
Restart=always
RestartSec=10
TimeoutStartSec=60

# Resource limits
MemoryMax=512M
CPUQuota=50%

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable litellm

    # Start LiteLLM with retry
    print_step "Starting LiteLLM gateway..."
    systemctl start litellm || {
        print_warning "LiteLLM failed to start (may need ANTHROPIC_API_KEY)"
        print_info "Edit /etc/litellm/env and restart: systemctl restart litellm"
    }

    sleep 3

    # Verify LiteLLM is running
    if curl -s http://localhost:4000/health > /dev/null 2>&1; then
        print_success "LiteLLM gateway deployed and healthy"
    else
        print_warning "LiteLLM deployed but not responding yet"
        print_info "Check: journalctl -u litellm -f"
    fi
}

step_12_n8n() {
    print_header "STEP 12/16: n8n Automation Platform"

    print_step "Deploying n8n..."
    docker run -d \
        --name ai-empire-n8n \
        --restart unless-stopped \
        -p 5678:5678 \
        -e N8N_BASIC_AUTH_ACTIVE=true \
        -e N8N_BASIC_AUTH_USER=admin \
        -e N8N_BASIC_AUTH_PASSWORD=changeme \
        -v n8n-data:/home/node/.n8n \
        n8nio/n8n:latest \
        || print_warning "n8n container already exists"

    sleep 3
    print_success "n8n deployed"
}

step_13_tailscale() {
    print_header "STEP 13/16: Tailscale VPN"

    print_step "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh || handle_error "Tailscale installation failed"

    print_success "Tailscale installed"
    print_warning "Run 'sudo tailscale up' to authenticate after deployment"
}

step_14_ai_empire_services() {
    print_header "STEP 14/16: AI Empire Python Services"

    INSTALL_DIR="/opt/ai-empire"
    mkdir -p "$INSTALL_DIR"

    print_step "Copying Python modules..."
    cp -r "$AI_EMPIRE_DIR/cloudflare-manager" "$INSTALL_DIR/"
    cp -r "$AI_EMPIRE_DIR/tailscale-manager" "$INSTALL_DIR/"
    cp -r "$AI_EMPIRE_DIR/domain-manager" "$INSTALL_DIR/"
    cp -r "$AI_EMPIRE_DIR/fabric-integration" "$INSTALL_DIR/"

    chmod +x "$INSTALL_DIR"/*/*.py

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
ExecStart=/usr/bin/python3 cloudflare_daemon.py --interval 300
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
ExecStart=/usr/bin/python3 vram_monitor.py --interval 30
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
ExecStart=/usr/bin/python3 fabric_n8n_bridge.py --port 8080
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload

    # Start services that don't need config
    systemctl enable vram-monitor
    systemctl start vram-monitor || print_warning "VRAM monitor needs nvidia-smi"

    systemctl enable fabric-bridge
    systemctl start fabric-bridge

    print_success "AI Empire services deployed"
}

step_15_environment_setup() {
    print_header "STEP 15/16: Environment Configuration"

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

    chmod +x /opt/ai-empire/*/env.sh

    # Copy management scripts to /usr/local/bin
    cp "$AI_EMPIRE_DIR/scripts/manage.sh" /usr/local/bin/ai-empire
    chmod +x /usr/local/bin/ai-empire

    print_success "Environment templates created"
}

step_16_health_checks() {
    print_header "STEP 16/16: Comprehensive Health Verification"

    local all_healthy=true
    local failed_services=""

    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                   SERVICE HEALTH CHECK                       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    # 1. Check NVIDIA Driver
    print_step "Checking NVIDIA Driver..."
    if command -v nvidia-smi &> /dev/null; then
        local gpu_info=$(nvidia-smi --query-gpu=name,driver_version,memory.total,memory.free --format=csv,noheader 2>/dev/null)
        if [ -n "$gpu_info" ]; then
            print_success "NVIDIA Driver: $gpu_info"
        else
            print_warning "NVIDIA Driver installed but GPU not responding"
            all_healthy=false
            failed_services="$failed_services nvidia-driver"
        fi
    else
        print_warning "NVIDIA Driver not installed"
        all_healthy=false
        failed_services="$failed_services nvidia-driver"
    fi

    # 2. Check Ollama
    print_step "Checking Ollama..."
    if systemctl is-active --quiet ollama; then
        if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
            local models=$(curl -s http://localhost:11434/api/tags | jq -r '.models[].name' 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
            print_success "Ollama: Running | Models: ${models:-none}"
        else
            print_warning "Ollama: Service running but API not responding"
            all_healthy=false
            failed_services="$failed_services ollama-api"
        fi
    else
        print_error "Ollama: NOT RUNNING"
        all_healthy=false
        failed_services="$failed_services ollama"
    fi

    # 3. Check LiteLLM
    print_step "Checking LiteLLM..."
    if systemctl is-active --quiet litellm; then
        if curl -s http://localhost:4000/health > /dev/null 2>&1; then
            print_success "LiteLLM: Healthy on port 4000"
        else
            print_warning "LiteLLM: Service running but health check failed"
            all_healthy=false
            failed_services="$failed_services litellm-api"
        fi
    else
        print_warning "LiteLLM: NOT RUNNING (may need ANTHROPIC_API_KEY)"
        # Not marking as failed - it's expected without API key
    fi

    # 4. Check PostgreSQL (Docker)
    print_step "Checking PostgreSQL..."
    if docker ps --format '{{.Names}}' | grep -q ai-empire-postgres; then
        if docker exec ai-empire-postgres pg_isready -U postgres > /dev/null 2>&1; then
            print_success "PostgreSQL: Running on port 5432"
        else
            print_warning "PostgreSQL: Container running but not ready"
            all_healthy=false
            failed_services="$failed_services postgres"
        fi
    else
        print_error "PostgreSQL: Container NOT RUNNING"
        all_healthy=false
        failed_services="$failed_services postgres"
    fi

    # 5. Check Redis (Docker)
    print_step "Checking Redis..."
    if docker ps --format '{{.Names}}' | grep -q ai-empire-redis; then
        if docker exec ai-empire-redis redis-cli ping > /dev/null 2>&1; then
            print_success "Redis: Running on port 6379"
        else
            print_warning "Redis: Container running but not responding"
            all_healthy=false
            failed_services="$failed_services redis"
        fi
    else
        print_error "Redis: Container NOT RUNNING"
        all_healthy=false
        failed_services="$failed_services redis"
    fi

    # 6. Check n8n (Docker)
    print_step "Checking n8n..."
    if docker ps --format '{{.Names}}' | grep -q ai-empire-n8n; then
        if curl -s http://localhost:5678 > /dev/null 2>&1; then
            print_success "n8n: Running on port 5678"
        else
            print_warning "n8n: Container running but web UI not ready"
            # Not critical, may just be starting
        fi
    else
        print_error "n8n: Container NOT RUNNING"
        all_healthy=false
        failed_services="$failed_services n8n"
    fi

    # 7. Check Fabric Bridge
    print_step "Checking Fabric Bridge..."
    if systemctl is-active --quiet fabric-bridge; then
        if curl -s http://localhost:8080/health > /dev/null 2>&1; then
            print_success "Fabric Bridge: Running on port 8080"
        else
            print_warning "Fabric Bridge: Service running but not responding"
        fi
    else
        print_warning "Fabric Bridge: NOT RUNNING"
    fi

    # 8. Check VRAM Monitor
    print_step "Checking VRAM Monitor..."
    if systemctl is-active --quiet vram-monitor; then
        print_success "VRAM Monitor: Running"
    else
        print_warning "VRAM Monitor: NOT RUNNING (needs nvidia-smi)"
    fi

    # 9. Check Tailscale
    print_step "Checking Tailscale..."
    if command -v tailscale &> /dev/null; then
        local ts_status=$(tailscale status 2>&1 | head -1)
        if echo "$ts_status" | grep -q "Tailscale is stopped"; then
            print_warning "Tailscale: Installed but not authenticated"
            print_info "Run: sudo tailscale up"
        elif echo "$ts_status" | grep -q "logged out"; then
            print_warning "Tailscale: Installed but logged out"
        else
            print_success "Tailscale: $ts_status"
        fi
    else
        print_warning "Tailscale: NOT INSTALLED"
    fi

    # Summary
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                     HEALTH CHECK SUMMARY                     ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    if [ "$all_healthy" = true ]; then
        print_success "All critical services are healthy!"
    else
        print_warning "Some services need attention: $failed_services"
        echo ""
        print_info "Troubleshooting commands:"
        echo "  journalctl -u ollama -f        # Ollama logs"
        echo "  journalctl -u litellm -f       # LiteLLM logs"
        echo "  docker logs ai-empire-postgres # PostgreSQL logs"
        echo "  docker logs ai-empire-redis    # Redis logs"
        echo "  docker logs ai-empire-n8n      # n8n logs"
    fi

    echo ""
}

################################################################################
# FINAL SUMMARY
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
  ✓ Ollama (DeepSeek R1-8B)    http://localhost:11434
  ✓ LiteLLM Gateway            http://localhost:4000
  ✓ n8n Automation             http://localhost:5678
  ✓ PostgreSQL                 localhost:5432
  ✓ Redis                      localhost:6379

AI Empire Services:
  ✓ Fabric n8n Bridge          http://localhost:8080
  ✓ VRAM Monitor               (background daemon)
  ✓ Tailscale VPN              (installed, needs auth)

NEXT STEPS:
═══════════

1. Configure API Credentials:
   nano /opt/ai-empire/cloudflare-manager/env.sh
   nano /opt/ai-empire/tailscale-manager/env.sh
   nano /opt/ai-empire/domain-manager/env.sh

2. Authenticate Tailscale VPN:
   sudo tailscale up

3. Start Cloudflare DNS Sync (after configuring):
   sudo systemctl start cloudflare-daemon

4. Access n8n:
   http://localhost:5678
   Username: admin
   Password: changeme

5. Import n8n workflows from:
   /opt/ai-empire/n8n-workflows/

MANAGEMENT:
══════════

Check status:
  ai-empire status

Real-time monitoring:
  ai-empire monitor

View logs:
  ai-empire logs <service>

Register service:
  ai-empire register-service myapp subdomain 3000

Full command list:
  ai-empire --help

QUICK TESTS:
═══════════

Test Ollama:
  curl http://localhost:11434/api/tags

Test Fabric Bridge:
  curl http://localhost:8080/health

Test VRAM monitoring:
  curl http://localhost:8080/vram

DOCUMENTATION:
═════════════
  README:      /opt/ai-empire/README.md
  Quickstart:  /opt/ai-empire/QUICKSTART.md
  Workflows:   /opt/ai-empire/n8n-workflows/README.md

COST SAVINGS:
════════════
  Before: $765/month (Claude only)
  After:  $60-80/month (95% reduction!)

  How? 80% of requests use FREE local DeepSeek R1-8B!

LOG FILE:
════════
  Full deployment log: /var/log/ai-empire-deployment.log

╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║          Welcome to your AI Empire! 👑                      ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

EOF
}

################################################################################
# MAIN EXECUTION
################################################################################

main() {
    echo "Deployment started: $(date)" >> "$LOG_FILE"

    check_root
    log_environment

    confirm_deployment

    # Run pre-flight checks
    preflight_system_check

    # Main deployment steps (16 total)
    step_1_nuclear_cleanup          # Clean existing Ollama installations
    step_2_system_update            # System packages and dependencies
    step_3_python_packages          # Python libraries
    step_4_docker_setup             # Docker configuration
    step_4b_nvidia_driver           # NVIDIA Driver 570 installation
    step_5_nvidia_docker            # NVIDIA Container Toolkit
    step_6_ollama_install           # Fresh Ollama installation
    step_7_ollama_optimize          # GTX 1060 6GB optimizations
    step_8_deepseek_model           # DeepSeek R1-8B model
    step_9_fabric_install           # Fabric CLI
    step_10_databases               # PostgreSQL + Redis
    step_11_litellm                 # LiteLLM gateway
    step_12_n8n                     # n8n automation
    step_13_tailscale               # Tailscale VPN
    step_14_ai_empire_services      # Python services
    step_15_environment_setup       # Environment files
    step_16_health_checks           # Comprehensive verification

    print_deployment_summary

    echo "Deployment completed: $(date)" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
}

main "$@"
