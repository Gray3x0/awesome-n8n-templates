#!/bin/bash

################################################################################
# Ultimate Ollama Enhancement Suite Installer
# Optimized for GTX 1060 6GB / Ubuntu 24.04 LTS
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
INSTALL_DIR="$HOME/ollama-suite"
PROJECTS_DIR="$INSTALL_DIR/projects"
DATA_DIR="$INSTALL_DIR/data"
LOGS_DIR="$INSTALL_DIR/logs"
BACKUP_DIR="$INSTALL_DIR/backups"

# System specs
GPU_VRAM="6GB"
CUDA_VERSION="12.4"

# Print functions
print_header() {
    echo -e "\n${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${MAGENTA}$1${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}\n"
}

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

# Create directory structure
create_directories() {
    print_status "Creating directory structure..."
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$PROJECTS_DIR"
    mkdir -p "$DATA_DIR"/{models,embeddings,vector-db,rag-docs}
    mkdir -p "$LOGS_DIR"
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$INSTALL_DIR/configs"
    mkdir -p "$INSTALL_DIR/scripts"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"

    # Check if running Ubuntu 24.04
    if ! grep -q "24.04" /etc/os-release 2>/dev/null; then
        print_warning "This script is optimized for Ubuntu 24.04 LTS"
    fi

    # Check for NVIDIA GPU
    if ! command -v nvidia-smi &> /dev/null; then
        print_error "NVIDIA drivers not found. Please install NVIDIA drivers first."
        exit 1
    fi

    print_status "NVIDIA GPU detected:"
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader

    # Check for Docker
    if ! command -v docker &> /dev/null; then
        print_warning "Docker not found. Installing Docker..."
        install_docker
    else
        print_status "Docker found: $(docker --version)"
    fi

    # Check for Docker Compose
    if ! command -v docker compose &> /dev/null; then
        print_warning "Docker Compose not found. Installing..."
        install_docker_compose
    else
        print_status "Docker Compose found"
    fi

    # Check for Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 not found. Installing..."
        sudo apt update && sudo apt install -y python3 python3-pip python3-venv
    else
        print_status "Python found: $(python3 --version)"
    fi

    # Check for Node.js
    if ! command -v node &> /dev/null; then
        print_warning "Node.js not found. Installing..."
        install_nodejs
    else
        print_status "Node.js found: $(node --version)"
    fi

    # Check for Git
    if ! command -v git &> /dev/null; then
        sudo apt update && sudo apt install -y git
    fi

    print_status "All prerequisites checked!"
}

# Install Docker
install_docker() {
    print_status "Installing Docker..."

    # Remove old versions
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    # Install prerequisites
    sudo apt update
    sudo apt install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    # Set up repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker Engine
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Add user to docker group
    sudo usermod -aG docker $USER

    # Install NVIDIA Container Toolkit
    print_status "Installing NVIDIA Container Toolkit..."
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
    curl -s -L https://nvidia.github.io/libnvidia-container/gpgkey | sudo apt-key add -
    curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

    sudo apt update
    sudo apt install -y nvidia-container-toolkit
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker

    print_status "Docker installed successfully!"
}

# Install Docker Compose
install_docker_compose() {
    DOCKER_COMPOSE_VERSION="v2.24.0"
    sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
}

# Install Node.js
install_nodejs() {
    print_status "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs
    print_status "Node.js installed: $(node --version)"
}

# Install Ollama core
install_ollama_core() {
    print_header "Installing Ollama Core"

    # Install Ollama
    print_status "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh

    # Wait for service to start
    sleep 3

    # Stop service for configuration
    sudo systemctl stop ollama

    # Create optimized configuration for GTX 1060
    print_status "Configuring Ollama for GTX 1060 6GB..."
    sudo mkdir -p /etc/systemd/system/ollama.service.d
    sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null << 'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_ORIGINS=*"
Environment="OLLAMA_KV_CACHE_TYPE=q8_0"
Environment="OLLAMA_FLASH_ATTENTION=1"
Environment="OLLAMA_NUM_PARALLEL=1"
Environment="OLLAMA_MAX_LOADED_MODELS=1"
Environment="CUDA_VISIBLE_DEVICES=0"
Environment="OLLAMA_MAX_VRAM=5.5GB"
Environment="OLLAMA_DEBUG=0"
EOF

    # Reload and start
    sudo systemctl daemon-reload
    sudo systemctl enable ollama
    sudo systemctl start ollama

    # Wait for service
    sleep 5

    # Verify installation
    if systemctl is-active --quiet ollama; then
        print_status "Ollama service is running!"
    else
        print_error "Ollama service failed to start"
        sudo journalctl -u ollama -n 50
        exit 1
    fi

    # Install Python client
    pip install ollama --break-system-packages 2>/dev/null || pip install ollama

    print_status "Ollama core installation complete!"
}

# Download recommended models
download_models() {
    print_header "Downloading Recommended Models"

    local models=(
        "deepseek-r1:7b"
        "qwen2.5:7b"
        "llama3.2:3b"
        "nomic-embed-text"
        "starcoder2:3b"
    )

    print_info "The following models will be downloaded (optimized for 6GB VRAM):"
    for model in "${models[@]}"; do
        echo "  - $model"
    done

    read -p "Download all models? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        for model in "${models[@]}"; do
            print_status "Downloading $model..."
            ollama pull "$model"
        done
        print_status "All models downloaded!"
    fi
}

# Show installation menu
show_menu() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║        Ultimate Ollama Enhancement Suite Installer              ║
║        Optimized for GTX 1060 6GB / Ubuntu 24.04 LTS            ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    echo -e "${GREEN}Select components to install:${NC}\n"

    echo "  ${BLUE}[1]${NC} Core Installation (Required)"
    echo "      → Ollama + GTX 1060 optimizations + Models"
    echo ""
    echo "  ${BLUE}[2]${NC} UI Frontends"
    echo "      → Open WebUI, LibreChat, AnythingLLM, Chatbot UI"
    echo ""
    echo "  ${BLUE}[3]${NC} RAG Systems"
    echo "      → PrivateGPT, LlamaIndex, Qdrant, Langflow"
    echo ""
    echo "  ${BLUE}[4]${NC} Agent Frameworks"
    echo "      → CrewAI, LangChain, LangGraph, AutoGPT"
    echo ""
    echo "  ${BLUE}[5]${NC} Performance Tools"
    echo "      → ExLlamaV2, llama.cpp, Benchmarking tools"
    echo ""
    echo "  ${BLUE}[6]${NC} Monitoring & Observability"
    echo "      → Langfuse, Prometheus, Grafana, Ollama Monitor"
    echo ""
    echo "  ${BLUE}[7]${NC} Security Hardening"
    echo "      → LLM Guard, Nginx, Fail2ban, Security configs"
    echo ""
    echo "  ${BLUE}[8]${NC} Integration Tools"
    echo "      → Continue.dev, Fabric, AIChat, n8n, Flowise, Dify"
    echo ""
    echo "  ${BLUE}[9]${NC} Voice Integration"
    echo "      → Whisper, Piper TTS, Voice Assistant"
    echo ""
    echo "  ${BLUE}[A]${NC} Install ALL Components (Mega Stack)"
    echo ""
    echo "  ${BLUE}[D]${NC} Docker Compose Stack Only"
    echo ""
    echo "  ${RED}[Q]${NC} Quit"
    echo ""
}

# Main installation flow
main() {
    print_header "Ultimate Ollama Enhancement Suite"

    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        print_error "Do not run this script as root!"
        exit 1
    fi

    # Create directories
    create_directories

    # Check prerequisites
    check_prerequisites

    # Show menu and get selection
    while true; do
        show_menu
        read -p "Enter your choice: " choice

        case $choice in
            1)
                install_ollama_core
                download_models
                ;;
            2)
                source "$INSTALL_DIR/scripts/install-ui-frontends.sh"
                install_ui_frontends
                ;;
            3)
                source "$INSTALL_DIR/scripts/install-rag-systems.sh"
                install_rag_systems
                ;;
            4)
                source "$INSTALL_DIR/scripts/install-agent-frameworks.sh"
                install_agent_frameworks
                ;;
            5)
                source "$INSTALL_DIR/scripts/install-performance-tools.sh"
                install_performance_tools
                ;;
            6)
                source "$INSTALL_DIR/scripts/install-monitoring.sh"
                install_monitoring
                ;;
            7)
                source "$INSTALL_DIR/scripts/install-security.sh"
                install_security
                ;;
            8)
                source "$INSTALL_DIR/scripts/install-integrations.sh"
                install_integrations
                ;;
            9)
                source "$INSTALL_DIR/scripts/install-voice.sh"
                install_voice
                ;;
            [aA])
                install_all_components
                ;;
            [dD])
                deploy_docker_stack
                ;;
            [qQ])
                print_status "Exiting installer. Thank you!"
                exit 0
                ;;
            *)
                print_error "Invalid choice. Please try again."
                sleep 2
                ;;
        esac

        read -p "Press Enter to continue..."
    done
}

# Install all components
install_all_components() {
    print_header "Installing ALL Components"

    install_ollama_core
    download_models

    # Install each module
    source "$INSTALL_DIR/scripts/install-ui-frontends.sh" && install_ui_frontends
    source "$INSTALL_DIR/scripts/install-rag-systems.sh" && install_rag_systems
    source "$INSTALL_DIR/scripts/install-agent-frameworks.sh" && install_agent_frameworks
    source "$INSTALL_DIR/scripts/install-performance-tools.sh" && install_performance_tools
    source "$INSTALL_DIR/scripts/install-monitoring.sh" && install_monitoring
    source "$INSTALL_DIR/scripts/install-security.sh" && install_security
    source "$INSTALL_DIR/scripts/install-integrations.sh" && install_integrations
    source "$INSTALL_DIR/scripts/install-voice.sh" && install_voice

    print_status "All components installed!"
    generate_summary
}

# Deploy Docker stack
deploy_docker_stack() {
    print_header "Deploying Docker Compose Mega Stack"

    cd "$INSTALL_DIR"
    docker compose -f docker-compose.yml up -d

    print_status "Docker stack deployed!"
    print_info "Access points:"
    print_info "  Open WebUI: http://localhost:3000"
    print_info "  LibreChat: http://localhost:3001"
    print_info "  AnythingLLM: http://localhost:3002"
    print_info "  Langfuse: http://localhost:3003"
    print_info "  Grafana: http://localhost:3004"
    print_info "  Qdrant: http://localhost:6333"
    print_info "  Flowise: http://localhost:3005"
    print_info "  n8n: http://localhost:5678"
}

# Generate installation summary
generate_summary() {
    print_header "Installation Summary"

    local summary_file="$INSTALL_DIR/INSTALLATION_SUMMARY.md"

    cat > "$summary_file" << EOF
# Ollama Enhancement Suite - Installation Summary

**Installation Date:** $(date)
**Installation Directory:** $INSTALL_DIR

## Installed Components

### Core
- [x] Ollama $(ollama --version 2>/dev/null || echo "N/A")
- [x] GTX 1060 6GB Optimizations Applied
- [x] KV Cache Quantization (q8_0)
- [x] Flash Attention Enabled

### Models Downloaded
$(ollama list 2>/dev/null || echo "Run 'ollama list' to see models")

### Services Running
$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "No Docker services")

## Access Points

| Service | URL | Default Port |
|---------|-----|--------------|
| Ollama API | http://localhost:11434 | 11434 |
| Open WebUI | http://localhost:3000 | 3000 |
| LibreChat | http://localhost:3001 | 3001 |
| AnythingLLM | http://localhost:3002 | 3002 |
| Langfuse | http://localhost:3003 | 3003 |
| Grafana | http://localhost:3004 | 3004 |
| Flowise | http://localhost:3005 | 3005 |
| n8n | http://localhost:5678 | 5678 |
| Qdrant | http://localhost:6333 | 6333 |

## Quick Commands

\`\`\`bash
# Check Ollama status
systemctl status ollama

# List running services
docker ps

# View Ollama logs
sudo journalctl -u ollama -f

# Restart all services
cd $INSTALL_DIR && docker compose restart

# Backup data
$INSTALL_DIR/scripts/backup.sh

# Update all components
$INSTALL_DIR/scripts/update-all.sh
\`\`\`

## Performance Tips for GTX 1060 6GB

1. **Use Q4_K_M models** for best balance (7B models ~4GB)
2. **Enable KV cache quantization** (already configured)
3. **Load one model at a time** (already configured)
4. **Monitor VRAM usage:** \`nvidia-smi -l 1\`
5. **Best models for your hardware:**
   - deepseek-r1:7b (reasoning tasks)
   - qwen2.5:7b (general + tools)
   - llama3.2:3b (fast inference)

## Troubleshooting

### Ollama not responding
\`\`\`bash
sudo systemctl restart ollama
sudo journalctl -u ollama -n 100
\`\`\`

### Out of VRAM errors
- Use smaller models (3B instead of 7B)
- Reduce context length
- Check \`nvidia-smi\` for other GPU processes

### Docker services won't start
\`\`\`bash
docker compose down
docker compose up -d
docker logs <service-name>
\`\`\`

## Next Steps

1. **Test Ollama:** \`ollama run llama3.2:3b "Hello!"\`
2. **Access Open WebUI:** http://localhost:3000
3. **Configure Tailscale** (if remote access needed)
4. **Set up automatic backups:** Edit \`$INSTALL_DIR/scripts/backup.sh\`
5. **Customize models:** Edit \`$INSTALL_DIR/configs/models.txt\`

## Documentation

- Main docs: $INSTALL_DIR/README.md
- Configuration: $INSTALL_DIR/configs/
- Scripts: $INSTALL_DIR/scripts/
- Logs: $LOGS_DIR/
- Backups: $BACKUP_DIR/

## Support

- Ollama docs: https://ollama.com/docs
- GitHub issues: https://github.com/ollama/ollama/issues
- Your installation log: $LOGS_DIR/install-$(date +%Y%m%d).log

EOF

    cat "$summary_file"
    print_status "Summary saved to: $summary_file"
}

# Run main installation
main "$@"
