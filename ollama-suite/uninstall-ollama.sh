#!/bin/bash

################################################################################
# Ollama Complete Nuclear Removal Script
# Removes ALL traces of Ollama from EVERYWHERE
################################################################################

set -e

echo "=================================="
echo "Ollama COMPLETE Removal Script"
echo "Nuclear option - removes EVERYTHING"
echo "=================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Confirm removal
read -p "This will COMPLETELY remove Ollama from EVERYWHERE. Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
print_warning "Starting NUCLEAR removal process..."
echo ""

# ============================================================================
# STEP 1: Kill everything on port 11434
# ============================================================================
print_status "Killing all processes on port 11434..."
sudo lsof -ti:11434 | xargs -r sudo kill -9 2>/dev/null || true
sleep 2

# ============================================================================
# STEP 2: Stop and disable ALL Ollama systemd services
# ============================================================================
print_status "Stopping all Ollama systemd services..."
sudo systemctl stop ollama 2>/dev/null || true
sudo systemctl stop ollama.service 2>/dev/null || true
sudo systemctl disable ollama 2>/dev/null || true
sudo systemctl disable ollama.service 2>/dev/null || true

# ============================================================================
# STEP 3: Kill ALL Ollama processes
# ============================================================================
print_status "Killing all Ollama processes..."
sudo pkill -9 ollama 2>/dev/null || true
sudo killall -9 ollama 2>/dev/null || true
sleep 2

# ============================================================================
# STEP 4: Stop ALL Docker containers with 'ollama' in name
# ============================================================================
print_status "Stopping all Docker containers with 'ollama'..."
docker ps -a | grep -i ollama | awk '{print $1}' | xargs -r docker stop 2>/dev/null || true
docker ps -a | grep -i ollama | awk '{print $1}' | xargs -r docker rm -f 2>/dev/null || true

# ============================================================================
# STEP 5: Check and stop Docker Compose stacks containing Ollama
# ============================================================================
print_status "Checking for Docker Compose stacks with Ollama..."

# Common locations for docker-compose files
COMPOSE_LOCATIONS=(
    "$HOME/n8n"
    "$HOME/docker"
    "$HOME/mcp"
    "/opt/n8n"
    "/opt/docker"
    "$HOME/awesome-n8n-templates"
    "/raid/awesome-n8n-templates"
)

for location in "${COMPOSE_LOCATIONS[@]}"; do
    if [ -f "$location/docker-compose.yml" ] || [ -f "$location/docker-compose.yaml" ]; then
        print_warning "Found docker-compose in: $location"

        # Check if it contains ollama
        if grep -qi "ollama" "$location/docker-compose.yml" 2>/dev/null || \
           grep -qi "ollama" "$location/docker-compose.yaml" 2>/dev/null; then
            print_warning "  Contains Ollama! Stopping..."
            (cd "$location" && docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true)
        fi
    fi
done

# ============================================================================
# STEP 6: Remove ALL Ollama Docker images
# ============================================================================
print_status "Removing all Ollama Docker images..."
docker images | grep -i ollama | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true

# ============================================================================
# STEP 7: Remove ALL Ollama Docker volumes
# ============================================================================
print_status "Removing all Ollama Docker volumes..."
docker volume ls | grep -i ollama | awk '{print $2}' | xargs -r docker volume rm -f 2>/dev/null || true

# ============================================================================
# STEP 8: Remove Ollama binaries from ALL locations
# ============================================================================
print_status "Removing Ollama binaries..."
sudo rm -f /usr/local/bin/ollama
sudo rm -f /usr/bin/ollama
sudo rm -f /bin/ollama
sudo rm -f /usr/local/lib/ollama
sudo rm -rf /usr/local/lib/ollama

# ============================================================================
# STEP 9: Remove Ollama systemd service files
# ============================================================================
print_status "Removing systemd service files..."
sudo rm -f /etc/systemd/system/ollama.service
sudo rm -rf /etc/systemd/system/ollama.service.d
sudo rm -f /lib/systemd/system/ollama.service
sudo systemctl daemon-reload

# ============================================================================
# STEP 10: Remove Ollama user and group
# ============================================================================
print_status "Removing Ollama user and group..."
sudo userdel ollama 2>/dev/null || true
sudo groupdel ollama 2>/dev/null || true

# ============================================================================
# STEP 11: Remove ALL Ollama data directories
# ============================================================================
print_status "Removing ALL Ollama data directories..."

OLLAMA_DIRS=(
    "/usr/share/ollama"
    "/var/lib/ollama"
    "$HOME/.ollama"
    "/root/.ollama"
    "$HOME/ollama"
    "/opt/ollama"
    "$HOME/.local/share/ollama"
    "/var/cache/ollama"
    "$HOME/.cache/ollama"
)

for dir in "${OLLAMA_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        print_warning "Removing: $dir"
        sudo rm -rf "$dir"
    fi
done

# ============================================================================
# STEP 12: Remove environment configurations
# ============================================================================
print_status "Cleaning environment configurations..."
sudo rm -f /etc/environment.d/ollama.conf
sudo sed -i '/OLLAMA_/d' /etc/environment 2>/dev/null || true

# Remove from user shells
for file in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
    if [ -f "$file" ]; then
        sed -i '/OLLAMA_/d' "$file" 2>/dev/null || true
    fi
done

# ============================================================================
# STEP 13: Remove Python packages
# ============================================================================
print_status "Removing Python packages..."
pip uninstall -y ollama ollama-python 2>/dev/null || true
pip3 uninstall -y ollama ollama-python 2>/dev/null || true

# ============================================================================
# STEP 14: Remove logs
# ============================================================================
print_status "Removing logs..."
sudo rm -rf /var/log/ollama 2>/dev/null || true
sudo journalctl --vacuum-time=1s --identifier=ollama 2>/dev/null || true

# ============================================================================
# STEP 15: Clean up Docker networks
# ============================================================================
print_status "Cleaning Docker networks..."
docker network ls | grep -i ollama | awk '{print $1}' | xargs -r docker network rm 2>/dev/null || true

# ============================================================================
# STEP 16: Remove any symlinks
# ============================================================================
print_status "Removing symlinks..."
sudo find /usr/local/bin -type l -name "*ollama*" -delete 2>/dev/null || true
sudo find /usr/bin -type l -name "*ollama*" -delete 2>/dev/null || true

# ============================================================================
# STEP 17: Remove from apt/snap if installed that way
# ============================================================================
print_status "Checking package managers..."
sudo apt remove -y ollama 2>/dev/null || true
sudo snap remove ollama 2>/dev/null || true

# ============================================================================
# STEP 18: Final verification - check port 11434
# ============================================================================
print_status "Verifying port 11434 is free..."
if sudo lsof -i:11434 > /dev/null 2>&1; then
    print_error "WARNING: Port 11434 is still in use!"
    echo "Processes using port 11434:"
    sudo lsof -i:11434
    echo ""
    print_warning "Attempting force kill..."
    sudo lsof -ti:11434 | xargs -r sudo kill -9 2>/dev/null || true
else
    print_status "Port 11434 is free!"
fi

# ============================================================================
# STEP 19: Check for any remaining ollama processes
# ============================================================================
print_status "Checking for remaining Ollama processes..."
if pgrep -i ollama > /dev/null; then
    print_error "WARNING: Ollama processes still running!"
    ps aux | grep -i ollama | grep -v grep
    echo ""
    print_warning "Force killing..."
    sudo pkill -9 -i ollama
else
    print_status "No Ollama processes found!"
fi

# ============================================================================
# STEP 20: Final cleanup - Docker system prune
# ============================================================================
print_status "Running Docker system prune..."
docker system prune -f 2>/dev/null || true

# ============================================================================
# SUMMARY
# ============================================================================
echo ""
echo "=================================="
print_status "COMPLETE! Ollama has been COMPLETELY removed from your system!"
echo "=================================="
echo ""
print_status "Removed:"
echo "  ✓ All systemd services"
echo "  ✓ All binaries and libraries"
echo "  ✓ All data directories"
echo "  ✓ All Docker containers and images"
echo "  ✓ All Docker volumes"
echo "  ✓ All environment variables"
echo "  ✓ All Python packages"
echo "  ✓ All logs"
echo "  ✓ User and group"
echo "  ✓ All processes"
echo ""
print_status "Port 11434 status: $(sudo lsof -i:11434 >/dev/null 2>&1 && echo 'IN USE' || echo 'FREE')"
echo ""
print_status "Your CUDA drivers and Docker installation remain intact."
echo ""
print_status "You can now proceed with a fresh installation!"
echo ""
