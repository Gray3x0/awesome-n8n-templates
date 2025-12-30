#!/bin/bash

################################################################################
# Ollama Complete Removal Script
# Removes all traces of Ollama and related installations
################################################################################

set -e

echo "=================================="
echo "Ollama Complete Removal Script"
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
read -p "This will completely remove Ollama and all related data. Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
print_warning "Starting removal process..."
echo ""

# Stop Ollama service
print_status "Stopping Ollama service..."
sudo systemctl stop ollama 2>/dev/null || true
sudo systemctl disable ollama 2>/dev/null || true

# Remove Ollama binary
print_status "Removing Ollama binary..."
sudo rm -f /usr/local/bin/ollama
sudo rm -f /usr/bin/ollama

# Remove Ollama service file
print_status "Removing systemd service..."
sudo rm -f /etc/systemd/system/ollama.service
sudo rm -rf /etc/systemd/system/ollama.service.d
sudo systemctl daemon-reload

# Remove Ollama user and group
print_status "Removing Ollama user and group..."
sudo userdel ollama 2>/dev/null || true
sudo groupdel ollama 2>/dev/null || true

# Remove Ollama data directories
print_status "Removing Ollama data directories..."
sudo rm -rf /usr/share/ollama
sudo rm -rf /var/lib/ollama
sudo rm -rf ~/.ollama
sudo rm -rf /root/.ollama

# Remove Docker volumes and containers
print_status "Removing Docker containers and volumes..."
docker stop ollama 2>/dev/null || true
docker rm ollama 2>/dev/null || true
docker volume rm ollama 2>/dev/null || true

# Remove models and cache
print_status "Removing models and cache..."
rm -rf ~/.cache/ollama 2>/dev/null || true
sudo rm -rf /var/cache/ollama 2>/dev/null || true

# Remove environment configurations
print_status "Cleaning environment configurations..."
sudo rm -f /etc/environment.d/ollama.conf
sudo sed -i '/OLLAMA_/d' /etc/environment 2>/dev/null || true

# Remove any pip packages
print_status "Removing Python packages..."
pip uninstall -y ollama ollama-python 2>/dev/null || true
pip3 uninstall -y ollama ollama-python 2>/dev/null || true

# Clean up any remaining processes
print_status "Killing any remaining Ollama processes..."
sudo pkill -9 ollama 2>/dev/null || true

# Remove logs
print_status "Removing logs..."
sudo rm -rf /var/log/ollama 2>/dev/null || true
sudo journalctl --vacuum-time=1s --identifier=ollama 2>/dev/null || true

# Clean up Docker networks
print_status "Cleaning Docker networks..."
docker network rm ollama-network 2>/dev/null || true

# Remove any symlinks
print_status "Removing symlinks..."
sudo find /usr/local/bin -type l -name "*ollama*" -delete 2>/dev/null || true

echo ""
print_status "Ollama has been completely removed from your system!"
print_warning "Your CUDA drivers and Docker installation remain intact."
echo ""
print_status "You can now proceed with a fresh installation."
echo ""
