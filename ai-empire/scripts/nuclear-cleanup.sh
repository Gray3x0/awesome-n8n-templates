#!/bin/bash

################################################################################
# NUCLEAR OLLAMA CLEANUP - Removes EVERY possible Ollama installation
# Searches the ENTIRE server for any trace of Ollama
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  $1"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n"
}

print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${BLUE}[i]${NC} $1"; }

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (sudo)"
        exit 1
    fi
}

print_header "NUCLEAR OLLAMA CLEANUP - COMPLETE SERVER SCAN"

check_root

# Counter for what we find
FOUND_COUNT=0

################################################################################
# STEP 1: Kill ALL Ollama processes everywhere
################################################################################
print_header "Step 1: Killing ALL Ollama Processes"

# Kill by process name
if pgrep -x ollama > /dev/null; then
    print_warning "Found Ollama processes, killing..."
    pkill -9 ollama 2>/dev/null || true
    sleep 2
    FOUND_COUNT=$((FOUND_COUNT + 1))
fi

# Kill anything on port 11434
if lsof -ti:11434 > /dev/null 2>&1; then
    print_warning "Found processes on port 11434, killing..."
    lsof -ti:11434 | xargs -r kill -9 2>/dev/null || true
    sleep 2
    FOUND_COUNT=$((FOUND_COUNT + 1))
fi

# Search for any process with 'ollama' in command line
OLLAMA_PIDS=$(ps aux | grep -i ollama | grep -v grep | awk '{print $2}' || true)
if [ -n "$OLLAMA_PIDS" ]; then
    print_warning "Found additional Ollama-related processes, killing..."
    echo "$OLLAMA_PIDS" | xargs -r kill -9 2>/dev/null || true
    FOUND_COUNT=$((FOUND_COUNT + 1))
fi

print_success "All Ollama processes terminated"

################################################################################
# STEP 2: Stop and disable ALL systemd services
################################################################################
print_header "Step 2: Removing ALL Systemd Services"

# Find all systemd services with 'ollama' in name
SERVICES=$(systemctl list-units --all --type=service | grep -i ollama | awk '{print $1}' || true)
if [ -n "$SERVICES" ]; then
    print_warning "Found systemd services:"
    echo "$SERVICES"
    for service in $SERVICES; do
        systemctl stop "$service" 2>/dev/null || true
        systemctl disable "$service" 2>/dev/null || true
        print_info "Stopped and disabled: $service"
    done
    FOUND_COUNT=$((FOUND_COUNT + 1))
fi

# Remove service files
find /etc/systemd/system -name "*ollama*" -type f -delete 2>/dev/null && print_info "Removed from /etc/systemd/system" || true
find /lib/systemd/system -name "*ollama*" -type f -delete 2>/dev/null && print_info "Removed from /lib/systemd/system" || true
find /usr/lib/systemd/system -name "*ollama*" -type f -delete 2>/dev/null && print_info "Removed from /usr/lib/systemd/system" || true

systemctl daemon-reload

print_success "All systemd services removed"

################################################################################
# STEP 3: Remove ALL Docker containers, images, and volumes
################################################################################
print_header "Step 3: Removing ALL Docker Ollama Instances"

# Stop and remove containers
CONTAINERS=$(docker ps -a --format '{{.Names}}' | grep -i ollama || true)
if [ -n "$CONTAINERS" ]; then
    print_warning "Found Docker containers:"
    echo "$CONTAINERS"
    echo "$CONTAINERS" | xargs -r docker rm -f
    FOUND_COUNT=$((FOUND_COUNT + 1))
fi

# Remove images
IMAGES=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep -i ollama || true)
if [ -n "$IMAGES" ]; then
    print_warning "Found Docker images:"
    echo "$IMAGES"
    echo "$IMAGES" | xargs -r docker rmi -f
    FOUND_COUNT=$((FOUND_COUNT + 1))
fi

# Remove volumes
VOLUMES=$(docker volume ls --format '{{.Name}}' | grep -i ollama || true)
if [ -n "$VOLUMES" ]; then
    print_warning "Found Docker volumes:"
    echo "$VOLUMES"
    echo "$VOLUMES" | xargs -r docker volume rm -f
    FOUND_COUNT=$((FOUND_COUNT + 1))
fi

# Remove networks
NETWORKS=$(docker network ls --format '{{.Name}}' | grep -i ollama || true)
if [ -n "$NETWORKS" ]; then
    print_warning "Found Docker networks:"
    echo "$NETWORKS"
    echo "$NETWORKS" | xargs -r docker network rm
    FOUND_COUNT=$((FOUND_COUNT + 1))
fi

print_success "All Docker resources removed"

################################################################################
# STEP 4: Check ALL Docker Compose stacks across the entire server
################################################################################
print_header "Step 4: Scanning ALL Docker Compose Stacks"

# Search common locations and user homes
COMPOSE_SEARCH_PATHS=(
    "/root"
    "/home"
    "/opt"
    "/srv"
    "/var/lib"
    "/data"
    "/mnt"
    "/raid"
)

for base_path in "${COMPOSE_SEARCH_PATHS[@]}"; do
    if [ -d "$base_path" ]; then
        print_info "Scanning $base_path for docker-compose files..."

        # Find all docker-compose files
        find "$base_path" -name "docker-compose.yml" -o -name "docker-compose.yaml" 2>/dev/null | while read -r compose_file; do
            if grep -qi "ollama" "$compose_file" 2>/dev/null; then
                print_warning "Found Ollama in: $compose_file"
                compose_dir=$(dirname "$compose_file")

                # Try to stop the stack
                (cd "$compose_dir" && docker compose down 2>/dev/null || docker-compose down 2>/dev/null) || true
                print_info "Stopped stack in: $compose_dir"
                FOUND_COUNT=$((FOUND_COUNT + 1))
            fi
        done
    fi
done

print_success "All Docker Compose stacks checked"

################################################################################
# STEP 5: Remove package manager installations FIRST
################################################################################
print_header "Step 5: Removing Package Manager Installations"

# Snap (must be removed before trying to delete read-only files)
if command -v snap &> /dev/null; then
    if snap list 2>/dev/null | grep -q ollama; then
        print_warning "Found Snap package, removing..."
        snap remove ollama --purge 2>/dev/null || true
        FOUND_COUNT=$((FOUND_COUNT + 1))
        sleep 2
    fi
fi

# Flatpak
if command -v flatpak &> /dev/null; then
    if flatpak list 2>/dev/null | grep -qi ollama; then
        print_warning "Found Flatpak package, removing..."
        flatpak uninstall -y ollama 2>/dev/null || true
        FOUND_COUNT=$((FOUND_COUNT + 1))
    fi
fi

# APT
if command -v apt &> /dev/null; then
    if dpkg -l | grep -qi ollama; then
        print_warning "Found APT package, removing..."
        apt remove --purge -y ollama 2>/dev/null || true
        apt autoremove -y 2>/dev/null || true
        FOUND_COUNT=$((FOUND_COUNT + 1))
    fi
fi

print_success "Package managers checked"

################################################################################
# STEP 6: Remove ALL Ollama binaries from everywhere
################################################################################
print_header "Step 6: Removing ALL Ollama Binaries"

# Common binary locations (snap/bin will be gone after snap removal)
BINARY_PATHS=(
    "/usr/local/bin/ollama"
    "/usr/bin/ollama"
    "/bin/ollama"
    "/opt/ollama"
    "$HOME/.local/bin/ollama"
)

for bin_path in "${BINARY_PATHS[@]}"; do
    if [ -e "$bin_path" ]; then
        print_warning "Found binary: $bin_path"
        rm -rf "$bin_path"
        FOUND_COUNT=$((FOUND_COUNT + 1))
    fi
done

# Search for ollama binary in ALL user home directories
find /home -name "ollama" -type f -executable 2>/dev/null | while read -r binary; do
    print_warning "Found user binary: $binary"
    rm -f "$binary"
    FOUND_COUNT=$((FOUND_COUNT + 1))
done

# Search entire filesystem (can be slow but thorough)
# Skip read-only filesystems like /snap
print_info "Performing deep filesystem scan for ollama binaries..."
find / -name "ollama" -type f -executable \
    -not -path "/snap/*" \
    -not -path "/proc/*" \
    -not -path "/sys/*" \
    -not -path "*/ai-empire/*" \
    -not -path "*/awesome-n8n/*" \
    2>/dev/null | while read -r binary; do
    print_warning "Found binary: $binary"
    rm -f "$binary" 2>/dev/null || print_warning "Could not remove $binary (read-only?)"
    FOUND_COUNT=$((FOUND_COUNT + 1))
done

print_success "All binaries removed"

################################################################################
# STEP 7: Remove ALL Ollama data directories
################################################################################
print_header "Step 7: Removing ALL Data Directories"

# Standard data locations
DATA_DIRS=(
    "/usr/share/ollama"
    "/var/lib/ollama"
    "/opt/ollama"
    "$HOME/.ollama"
    "/root/.ollama"
)

for data_dir in "${DATA_DIRS[@]}"; do
    if [ -d "$data_dir" ]; then
        print_warning "Found data directory: $data_dir ($(du -sh "$data_dir" 2>/dev/null | cut -f1))"
        rm -rf "$data_dir"
        FOUND_COUNT=$((FOUND_COUNT + 1))
    fi
done

# Search ALL user home directories
find /home -name ".ollama" -type d 2>/dev/null | while read -r user_dir; do
    print_warning "Found user data: $user_dir ($(du -sh "$user_dir" 2>/dev/null | cut -f1))"
    rm -rf "$user_dir"
    FOUND_COUNT=$((FOUND_COUNT + 1))
done

# Check common data mount points
for mount_point in /mnt/* /media/* /data/* /raid/* /srv/*; do
    if [ -d "$mount_point/.ollama" ]; then
        print_warning "Found data on mount: $mount_point/.ollama"
        rm -rf "$mount_point/.ollama"
        FOUND_COUNT=$((FOUND_COUNT + 1))
    fi
    if [ -d "$mount_point/ollama" ]; then
        print_warning "Found data on mount: $mount_point/ollama"
        rm -rf "$mount_point/ollama"
        FOUND_COUNT=$((FOUND_COUNT + 1))
    fi
done

print_success "All data directories removed"

################################################################################
# STEP 8: Remove ALL configuration files
################################################################################
print_header "Step 8: Removing ALL Configuration Files"

# Config locations
find /etc -name "*ollama*" 2>/dev/null | while read -r config; do
    print_warning "Found config: $config"
    rm -rf "$config"
    FOUND_COUNT=$((FOUND_COUNT + 1))
done

# User configs
find /home -name "*ollama*" -path "*/.*" 2>/dev/null | while read -r config; do
    print_warning "Found user config: $config"
    rm -rf "$config"
    FOUND_COUNT=$((FOUND_COUNT + 1))
done

print_success "All configuration files removed"

################################################################################
# STEP 9: Remove environment variables and shell configs
################################################################################
print_header "Step 9: Cleaning Shell Configurations"

# Remove from common shell configs
SHELL_CONFIGS=(
    "/root/.bashrc"
    "/root/.zshrc"
    "/root/.profile"
    "/etc/environment"
    "/etc/profile"
)

for config in "${SHELL_CONFIGS[@]}"; do
    if [ -f "$config" ]; then
        if grep -qi ollama "$config" 2>/dev/null; then
            print_warning "Found Ollama references in: $config"
            sed -i '/ollama/Id' "$config"
            FOUND_COUNT=$((FOUND_COUNT + 1))
        fi
    fi
done

# User shell configs
find /home -name ".bashrc" -o -name ".zshrc" -o -name ".profile" 2>/dev/null | while read -r config; do
    if grep -qi ollama "$config" 2>/dev/null; then
        print_warning "Found Ollama in user config: $config"
        sed -i '/ollama/Id' "$config"
        FOUND_COUNT=$((FOUND_COUNT + 1))
    fi
done

print_success "Shell configurations cleaned"

################################################################################
# STEP 10: Check and remove cron jobs
################################################################################
print_header "Step 10: Checking Cron Jobs"

# System cron
for cron_dir in /etc/cron.* /var/spool/cron/*; do
    if [ -d "$cron_dir" ]; then
        find "$cron_dir" -type f -exec grep -l "ollama" {} \; 2>/dev/null | while read -r cron_file; do
            print_warning "Found Ollama in cron: $cron_file"
            sed -i '/ollama/d' "$cron_file"
            FOUND_COUNT=$((FOUND_COUNT + 1))
        done
    fi
done

print_success "Cron jobs checked"

################################################################################
# STEP 11: Final verification
################################################################################
print_header "Step 11: Final Verification"

# Check port 11434
if lsof -i:11434 > /dev/null 2>&1; then
    print_error "WARNING: Port 11434 still in use!"
    lsof -i:11434
else
    print_success "Port 11434 is free"
fi

# Check for running processes
if pgrep -x ollama > /dev/null 2>&1; then
    print_error "WARNING: Ollama processes still running!"
    pgrep -x ollama
else
    print_success "No Ollama processes running"
fi

# Check for remaining binaries
REMAINING_BINS=$(find / -name "ollama" -type f -executable 2>/dev/null | grep -v "ai-empire" | grep -v "awesome-n8n" || true)
if [ -n "$REMAINING_BINS" ]; then
    print_warning "Found remaining binaries:"
    echo "$REMAINING_BINS"
else
    print_success "No remaining binaries found"
fi

################################################################################
# Summary
################################################################################
print_header "CLEANUP COMPLETE"

cat << EOF

╔══════════════════════════════════════════════════════════════╗
║              NUCLEAR CLEANUP SUMMARY                         ║
╚══════════════════════════════════════════════════════════════╝

Total Ollama installations found and removed: $FOUND_COUNT

What was cleaned:
  ✓ All running processes killed
  ✓ All systemd services removed
  ✓ All Docker containers/images/volumes removed
  ✓ All Docker Compose stacks checked
  ✓ All binaries removed (system and user)
  ✓ All data directories removed
  ✓ All configuration files removed
  ✓ Package manager installations removed
  ✓ Shell configurations cleaned
  ✓ Cron jobs checked

Your server is now completely clean of Ollama!

Ready for fresh installation with:
  sudo bash scripts/deploy-everything.sh

EOF

if [ "$FOUND_COUNT" -eq 0 ]; then
    print_info "No Ollama installations were found on this server."
fi
