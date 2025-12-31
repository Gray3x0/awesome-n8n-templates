#!/bin/bash

################################################################################
# Update All Components Script
# Updates: Ollama, Docker images, Python packages, Git repos
################################################################################

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }

INSTALL_DIR="$HOME/ollama-suite"
PROJECTS_DIR="$INSTALL_DIR/projects"

echo "=================================="
echo "Ollama Suite Update Script"
echo "=================================="
echo ""

# 1. Update Ollama
print_status "Updating Ollama..."
curl -fsSL https://ollama.com/install.sh | sh
sudo systemctl restart ollama
sleep 3

# 2. Update Docker images
print_status "Updating Docker images..."
cd "$INSTALL_DIR"

if [ -f docker-compose.yml ]; then
    docker compose pull
    docker compose up -d
    print_status "Docker images updated"
fi

# 3. Update Python packages
print_status "Updating Python packages..."
PACKAGES=(
    "ollama"
    "langchain"
    "langchain-community"
    "llama-index"
    "crewai"
    "llm-guard"
    "langfuse"
    "qdrant-client"
)

for package in "${PACKAGES[@]}"; do
    pip install --upgrade "$package" --break-system-packages 2>/dev/null || \
    pip install --upgrade "$package" 2>/dev/null || true
done

# 4. Update Git repositories
print_status "Updating Git repositories..."

REPOS=(
    "open-webui"
    "LibreChat"
    "private-gpt"
    "llama.cpp"
    "exllamav2"
    "Auto-GPT"
)

for repo in "${REPOS[@]}"; do
    if [ -d "$PROJECTS_DIR/$repo" ]; then
        print_status "Updating $repo..."
        cd "$PROJECTS_DIR/$repo"
        git pull
    fi
done

# 5. Update Fabric
if command -v fabric &> /dev/null; then
    print_status "Updating Fabric patterns..."
    fabric --updatepatterns
fi

# 6. Update Go packages
if command -v go &> /dev/null; then
    print_status "Updating Go packages..."
    go install github.com/danielmiessler/fabric@latest
fi

# 7. Rebuild llama.cpp
if [ -d "$PROJECTS_DIR/llama.cpp" ]; then
    print_status "Rebuilding llama.cpp..."
    cd "$PROJECTS_DIR/llama.cpp"
    make clean && make LLAMA_CUDA=1 -j$(nproc)
fi

# 8. Clean up Docker
print_status "Cleaning Docker..."
docker system prune -f

print_status "Update complete!"
echo ""
echo "Restart recommended: sudo systemctl restart ollama"
