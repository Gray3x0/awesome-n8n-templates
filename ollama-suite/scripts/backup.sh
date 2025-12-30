#!/bin/bash

################################################################################
# Ollama Suite Backup Script
# Backs up: Models, Data, Configurations, Docker Volumes
################################################################################

INSTALL_DIR="$HOME/ollama-suite"
BACKUP_DIR="${INSTALL_DIR}/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="ollama-backup-${TIMESTAMP}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }

echo "=================================="
echo "Ollama Suite Backup"
echo "=================================="
echo ""

# Create backup directory
mkdir -p "$BACKUP_PATH"

# 1. Backup Ollama models
print_status "Backing up Ollama models..."
if [ -d ~/.ollama/models ]; then
    tar -czf "$BACKUP_PATH/ollama-models.tar.gz" -C ~/.ollama models
    print_status "Models backed up"
else
    print_warning "No models directory found"
fi

# 2. Backup Ollama configuration
print_status "Backing up Ollama configuration..."
if [ -f /etc/systemd/system/ollama.service.d/override.conf ]; then
    sudo cp /etc/systemd/system/ollama.service.d/override.conf "$BACKUP_PATH/"
fi

# 3. Backup data directory
print_status "Backing up data directory..."
if [ -d "$INSTALL_DIR/data" ]; then
    tar -czf "$BACKUP_PATH/data.tar.gz" -C "$INSTALL_DIR" data
    print_status "Data backed up"
fi

# 4. Backup configurations
print_status "Backing up configurations..."
if [ -d "$INSTALL_DIR/configs" ]; then
    tar -czf "$BACKUP_PATH/configs.tar.gz" -C "$INSTALL_DIR" configs
fi

# 5. Backup Docker volumes
print_status "Backing up Docker volumes..."

VOLUMES=(
    "open-webui-data"
    "qdrant-data"
    "langfuse-db-data"
    "n8n-data"
    "flowise-data"
)

mkdir -p "$BACKUP_PATH/docker-volumes"

for volume in "${VOLUMES[@]}"; do
    if docker volume inspect "$volume" &>/dev/null; then
        print_status "Backing up volume: $volume"
        docker run --rm \
            -v "$volume:/data" \
            -v "$BACKUP_PATH/docker-volumes:/backup" \
            alpine \
            tar -czf "/backup/${volume}.tar.gz" -C /data .
    fi
done

# 6. Backup project configurations
print_status "Backing up project configurations..."
CONFIGS=(
    "$HOME/.continue/config.json"
    "$HOME/.config/fabric/config.yaml"
    "$HOME/.config/aichat/config.yaml"
)

mkdir -p "$BACKUP_PATH/user-configs"

for config in "${CONFIGS[@]}"; do
    if [ -f "$config" ]; then
        cp "$config" "$BACKUP_PATH/user-configs/" 2>/dev/null || true
    fi
done

# 7. Create backup metadata
print_status "Creating backup metadata..."
cat > "$BACKUP_PATH/backup-info.txt" << EOF
Ollama Suite Backup
===================

Date: $(date)
Hostname: $(hostname)
User: $(whoami)

System Info:
- OS: $(lsb_release -d | cut -f2)
- Kernel: $(uname -r)
- GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo "N/A")

Ollama Version: $(ollama --version 2>/dev/null || echo "N/A")

Backed up components:
- Ollama models
- Ollama configuration
- Data directory
- Configuration files
- Docker volumes
- User configurations

Backup size: $(du -sh "$BACKUP_PATH" | cut -f1)
EOF

# 8. Create restore script
print_status "Creating restore script..."
cat > "$BACKUP_PATH/restore.sh" << 'RESTORE_SCRIPT'
#!/bin/bash

echo "Ollama Suite Restore"
echo "===================="
echo ""

BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/ollama-suite"

read -p "This will restore from backup. Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Stop services
echo "Stopping services..."
sudo systemctl stop ollama
cd "$INSTALL_DIR" && docker compose down

# Restore models
if [ -f "$BACKUP_DIR/ollama-models.tar.gz" ]; then
    echo "Restoring Ollama models..."
    tar -xzf "$BACKUP_DIR/ollama-models.tar.gz" -C ~/.ollama/
fi

# Restore configuration
if [ -f "$BACKUP_DIR/override.conf" ]; then
    echo "Restoring Ollama configuration..."
    sudo mkdir -p /etc/systemd/system/ollama.service.d
    sudo cp "$BACKUP_DIR/override.conf" /etc/systemd/system/ollama.service.d/
    sudo systemctl daemon-reload
fi

# Restore data
if [ -f "$BACKUP_DIR/data.tar.gz" ]; then
    echo "Restoring data..."
    tar -xzf "$BACKUP_DIR/data.tar.gz" -C "$INSTALL_DIR"
fi

# Restore configs
if [ -f "$BACKUP_DIR/configs.tar.gz" ]; then
    echo "Restoring configurations..."
    tar -xzf "$BACKUP_DIR/configs.tar.gz" -C "$INSTALL_DIR"
fi

# Restore Docker volumes
if [ -d "$BACKUP_DIR/docker-volumes" ]; then
    echo "Restoring Docker volumes..."
    for volume_backup in "$BACKUP_DIR/docker-volumes"/*.tar.gz; do
        if [ -f "$volume_backup" ]; then
            volume_name=$(basename "$volume_backup" .tar.gz)
            echo "  Restoring: $volume_name"
            docker volume create "$volume_name"
            docker run --rm \
                -v "$volume_name:/data" \
                -v "$BACKUP_DIR/docker-volumes:/backup" \
                alpine \
                sh -c "rm -rf /data/* && tar -xzf /backup/${volume_name}.tar.gz -C /data"
        fi
    done
fi

# Restore user configs
if [ -d "$BACKUP_DIR/user-configs" ]; then
    echo "Restoring user configurations..."
    cp -r "$BACKUP_DIR/user-configs/"* ~/ 2>/dev/null || true
fi

# Restart services
echo "Restarting services..."
sudo systemctl start ollama
cd "$INSTALL_DIR" && docker compose up -d

echo ""
echo "Restore complete!"
echo "Check services with: docker ps"
RESTORE_SCRIPT

chmod +x "$BACKUP_PATH/restore.sh"

# 9. Compress entire backup
print_status "Compressing backup..."
cd "$BACKUP_DIR"
tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"
BACKUP_SIZE=$(du -sh "${BACKUP_NAME}.tar.gz" | cut -f1)

# Clean up uncompressed backup
rm -rf "$BACKUP_NAME"

echo ""
print_status "Backup complete!"
echo ""
echo "Backup file: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
echo "Backup size: $BACKUP_SIZE"
echo ""
echo "To restore from this backup:"
echo "  1. Extract: tar -xzf ${BACKUP_NAME}.tar.gz"
echo "  2. Run: cd ${BACKUP_NAME} && ./restore.sh"
echo ""

# Optional: Upload to remote storage
if command -v rclone &> /dev/null; then
    read -p "Upload backup to remote storage? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Uploading to remote storage..."
        rclone copy "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" remote:ollama-backups/
        print_status "Upload complete!"
    fi
fi

# Clean old backups (keep last 5)
print_status "Cleaning old backups..."
cd "$BACKUP_DIR"
ls -t ollama-backup-*.tar.gz | tail -n +6 | xargs -r rm
print_status "Old backups cleaned (kept last 5)"

echo ""
echo "Backup process finished!"
