# AI Empire Unified Deployment Guide

## Quick Start (One Command)

```bash
cd /home/user/awesome-n8n-templates
git pull origin claude/optimize-ollama-ubuntu-A1mnu
sudo bash ai-empire/scripts/deploy-everything-v2.sh
```

## What This Script Does

### 16 Automated Steps:

1. **NVIDIA Driver** - Installs nvidia-driver-545 for GTX 1060 on Ubuntu 24.04
2. **Nuclear Cleanup** - Removes old Ollama/Podman installations (preserves data)
3. **Storage Setup** - Creates /raid/ structure, migrates from /raid/n8n-mcp-suite/
4. **System Dependencies** - Installs all required packages
5. **Docker CE** - Installs Docker Community Edition (not docker.io)
6. **NVIDIA Container Toolkit** - GPU passthrough for Docker containers
7. **Python Packages** - Creates venv at /opt/ai-empire/venv/ with all dependencies
8. **Data Migration** - Safely migrates PostgreSQL, Redis, Ollama, n8n data
9. **Ollama Install** - Latest Ollama with official installer
10. **GTX 1060 Optimization** - q4_0 KV cache, 5.5GB VRAM limit, Flash Attention
11. **Models** - Pulls deepseek-r1:7b (7B not 8B for 6GB VRAM)
12. **Fabric CLI** - Installs Go 1.21.0 + Fabric with 300+ patterns
13. **Databases** - PostgreSQL + Redis via docker-compose
14. **LiteLLM** - Unified API gateway with Ollama + Claude routing
15. **n8n** - Automation platform with PostgreSQL backend
16. **Services + Health** - Systemd services + comprehensive health checks

## Hardware Requirements

- **CPU**: Intel Xeon 5675 (6-core) ✓
- **RAM**: 28GB ✓
- **GPU**: GTX 1060 6GB ✓
- **Storage**: 128GB SSD + 5.5TB RAID ✓
- **OS**: Ubuntu 24.04 Noble LTS ✓

## Critical GTX 1060 6GB Optimizations

### Why q4_0 Instead of q8_0?

```
q8_0 (full precision):
├── DeepSeek R1 8B: ~8GB VRAM (OOM on 6GB GPU ❌)
└── KV cache overhead: ~2GB

q4_0 (compressed):
├── DeepSeek R1 7B: ~4.5GB VRAM ✓
├── KV cache overhead: ~1GB (compressed)
└── Total: 5.5GB (0.5GB headroom) ✓
```

### Ollama Environment Variables

```bash
OLLAMA_MODELS=/raid/ollama/           # Use RAID for models
OLLAMA_KV_CACHE_TYPE=q4_0            # Compressed KV cache
OLLAMA_MAX_VRAM=5.5GB                # 0.5GB headroom
OLLAMA_FLASH_ATTENTION=1             # Memory-efficient attention
OLLAMA_MAX_LOADED_MODELS=1           # Prevent OOM
OLLAMA_NUM_PARALLEL=1                # Single request at a time
```

### Model Recommendations

**SUPPORTED (7B models for 6GB VRAM):**
- deepseek-r1:7b ✓
- llama2:7b ✓
- mistral:7b ✓
- codellama:7b ✓

**AVOID (will OOM on GTX 1060):**
- Any 8B+ models ❌
- Any 13B+ models ❌
- Multiple models loaded simultaneously ❌

## Storage Structure After Deployment

```
/
├── /opt/ai-empire/
│   ├── venv/                    # Python virtual environment
│   ├── compose/                 # docker-compose.yml
│   ├── cloudflare-manager/      # DNS automation
│   ├── domain-manager/          # Domain management
│   ├── fabric-integration/      # Fabric CLI integration
│   └── tailscale-manager/       # VPN management
│
└── /etc/
    ├── litellm/config.yaml      # LiteLLM gateway config
    └── systemd/system/          # All service files

/raid/
├── postgres/                    # PostgreSQL data (migrated)
├── redis/                       # Redis data (migrated)
├── ollama/                      # Ollama models (migrated)
├── n8n/                         # n8n workflows (migrated)
└── backups/                     # Automated backups
```

## Services Deployed

### Core Infrastructure

| Service | Port | Status | Description |
|---------|------|--------|-------------|
| Ollama | 11434 | ✓ | Local LLM inference (GTX 1060) |
| LiteLLM | 4000 | ✓ | Unified API gateway |
| n8n | 5678 | ✓ | Workflow automation |
| PostgreSQL | 5432 | ✓ | Database with pgvector |
| Redis | 6379 | ✓ | Caching + LiteLLM cache |

### Python Services (systemd)

| Service | Port | Status | Description |
|---------|------|--------|-------------|
| fabric-bridge | 8080 | ✓ | Fabric n8n integration |
| vram-monitor | - | ✓ | GPU memory monitoring |
| cloudflare-daemon | - | ⚠️ | Needs API key configuration |

## Post-Deployment Steps

### 1. Verify NVIDIA Driver

If driver was just installed, **reboot required**:

```bash
sudo reboot
```

After reboot, verify GPU:

```bash
nvidia-smi
```

Expected output:
```
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 545.xx.xx    Driver Version: 545.xx.xx    CUDA Version: 12.3   |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  NVIDIA GeForce GTX 1060 6GB   Off  | 00000000:01:00.0  On |         N/A |
| 40%   45C    P0    25W / 120W |   300MiB /  6144MiB  |      0%      Default |
+-------------------------------+----------------------+----------------------+
```

### 2. Configure API Credentials

```bash
# Cloudflare DNS automation
sudo nano /opt/ai-empire/cloudflare-manager/env.sh
# Add your CLOUDFLARE_API_TOKEN and ZONE_ID

# Tailscale VPN (if using)
sudo nano /opt/ai-empire/tailscale-manager/env.sh
# Add your TAILSCALE_API_KEY
```

### 3. Configure LiteLLM with Anthropic API Key

```bash
# Set environment variable
export ANTHROPIC_API_KEY="sk-ant-..."

# Restart LiteLLM
sudo systemctl restart litellm
```

### 4. Start Optional Services

```bash
# Cloudflare DNS sync (after configuring API key)
sudo systemctl start cloudflare-daemon

# Check status
sudo systemctl status cloudflare-daemon
```

### 5. Access n8n

```bash
# Open in browser
http://localhost:5678

# Default credentials:
Username: admin
Password: changeme

# CHANGE PASSWORD IMMEDIATELY after first login!
```

### 6. Import n8n Workflows

If you have existing workflows at `/raid/n8n-mcp-suite/n8n-workflows/`:

1. Navigate to n8n web UI: http://localhost:5678
2. Go to Workflows → Import from File
3. Select JSON files from `/raid/n8n/workflows/` (migrated location)
4. Or use the included templates:
   - `/opt/ai-empire/n8n-workflows/vram-aware-routing.json`
   - `/opt/ai-empire/n8n-workflows/fabric-content-extraction.json`

## Health Checks

### Automatic Health Check

The deployment script runs health checks at the end. Rerun anytime:

```bash
# Check all services
docker ps
sudo systemctl status ollama
sudo systemctl status litellm
sudo systemctl status vram-monitor
sudo systemctl status fabric-bridge

# Check GPU
nvidia-smi

# Test GPU in Docker
docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi
```

### Manual Service Checks

```bash
# Ollama
curl http://localhost:11434/api/tags

# LiteLLM
curl http://localhost:4000/health

# PostgreSQL
docker exec ai-empire-postgres pg_isready -U postgres

# Redis
docker exec ai-empire-redis redis-cli ping

# n8n
curl -I http://localhost:5678
```

## Logs & Debugging

### Deployment Log

```bash
tail -f /var/log/ai-empire-deployment.log
```

### Docker Logs

```bash
# All containers
docker ps

# Specific container
docker logs ai-empire-postgres
docker logs ai-empire-redis
docker logs ai-empire-n8n
```

### Systemd Service Logs

```bash
# Ollama
sudo journalctl -u ollama -f

# LiteLLM
sudo journalctl -u litellm -f

# VRAM Monitor
sudo journalctl -u vram-monitor -f

# Fabric Bridge
sudo journalctl -u fabric-bridge -f
```

## Testing Ollama with DeepSeek R1 7B

```bash
# List installed models
ollama list

# Test model (should use ~4.5GB VRAM)
ollama run deepseek-r1:7b "Explain quantum computing in simple terms"

# Monitor VRAM usage in another terminal
watch -n 1 nvidia-smi
```

## Testing LiteLLM Routing

```bash
# Test local Ollama route
curl http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-r1-7b",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'

# Test Claude API route (requires ANTHROPIC_API_KEY)
curl http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3-5-sonnet",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

## Troubleshooting

### Issue: nvidia-smi not found after installation

**Solution**: Reboot required
```bash
sudo reboot
```

### Issue: Ollama OOM (Out of Memory)

**Solution 1**: Check you're using 7B models (not 8B+)
```bash
ollama list
# If you see 8b or 13b models, remove them:
ollama rm model-name:8b
```

**Solution 2**: Verify q4_0 KV cache
```bash
sudo systemctl cat ollama | grep OLLAMA_KV_CACHE
# Should show: OLLAMA_KV_CACHE_TYPE=q4_0
```

**Solution 3**: Check VRAM usage
```bash
nvidia-smi
# Memory-Usage should be < 5.5GB
```

### Issue: Port conflicts (5678, 11434, etc.)

**Solution**: Check what's using the port
```bash
sudo lsof -i :5678
sudo lsof -i :11434

# Kill the process if safe
sudo kill -9 <PID>
```

### Issue: Docker containers won't start

**Solution**: Check logs
```bash
docker ps -a
docker logs <container-name>

# Restart docker-compose
cd /opt/ai-empire/compose
docker-compose down
docker-compose up -d
```

### Issue: PostgreSQL data migration failed

**Solution**: Restore from backup
```bash
# Find backup
ls -la /raid/backups/

# Restore manually
sudo rsync -av /raid/backups/pre-migration-*/postgres/ /raid/postgres/

# Restart container
docker restart ai-empire-postgres
```

## Updating the Deployment

To update with latest changes:

```bash
cd /home/user/awesome-n8n-templates
git pull origin claude/optimize-ollama-ubuntu-A1mnu

# Re-run deployment (skips cleanup)
sudo bash ai-empire/scripts/deploy-everything-v2.sh --skip-cleanup
```

## Command Reference

### Flags

```bash
# Skip nuclear cleanup (for re-deployments)
sudo bash deploy-everything-v2.sh --skip-cleanup

# Skip NVIDIA driver installation
sudo bash deploy-everything-v2.sh --skip-nvidia

# Both
sudo bash deploy-everything-v2.sh --skip-cleanup --skip-nvidia
```

### Service Management

```bash
# Start service
sudo systemctl start <service-name>

# Stop service
sudo systemctl stop <service-name>

# Restart service
sudo systemctl restart <service-name>

# Check status
sudo systemctl status <service-name>

# View logs
sudo journalctl -u <service-name> -f
```

### Docker Commands

```bash
# List running containers
docker ps

# List all containers (including stopped)
docker ps -a

# Stop all containers
docker stop $(docker ps -aq)

# Remove all containers
docker rm $(docker ps -aq)

# View logs
docker logs <container-name>

# docker-compose operations
cd /opt/ai-empire/compose
docker-compose up -d       # Start
docker-compose down        # Stop
docker-compose restart     # Restart
docker-compose logs -f     # View logs
```

## Performance Expectations

### GTX 1060 6GB with q4_0 KV Cache

| Model | Tokens/sec | VRAM Usage | Latency |
|-------|------------|------------|---------|
| deepseek-r1:7b | 15-20 | ~4.5GB | ~50ms |
| llama2:7b | 20-25 | ~4.0GB | ~40ms |
| mistral:7b | 18-22 | ~4.2GB | ~45ms |

### Expected System Resources

```
CPU Usage: 30-50% (Xeon 5675)
RAM Usage: 8-12GB / 28GB
GPU Usage: 70-90% during inference
GPU VRAM: 4-5.5GB / 6GB
```

## Security Notes

### Change Default Passwords

```bash
# n8n (via web UI)
http://localhost:5678 → Settings → Users

# PostgreSQL
docker exec -it ai-empire-postgres psql -U postgres
ALTER USER postgres WITH PASSWORD 'new-secure-password';

# Update in n8n docker-compose
sudo nano /opt/ai-empire/compose/docker-compose.yml
# Change DB_POSTGRESDB_PASSWORD
docker-compose up -d
```

### Firewall Configuration

```bash
# Allow local access only (default)
sudo ufw status

# If you need remote access (be careful!)
sudo ufw allow from <trusted-ip> to any port 5678  # n8n
sudo ufw allow from <trusted-ip> to any port 11434 # Ollama
```

## Cost Comparison

### Before (Cloud-Only)

```
Claude Opus API: $15/M tokens
Usage: 50M tokens/month
Cost: $750/month
```

### After (Hybrid with Local GTX 1060)

```
DeepSeek R1 7B (local): FREE
├── 90% of requests (simple tasks)
└── Cost: $0

Claude API (fallback): $15/M tokens
├── 10% of requests (complex tasks)
└── 5M tokens/month
└── Cost: $75/month

Total: $75/month (90% reduction!)
```

## Support

For issues:
1. Check deployment log: `/var/log/ai-empire-deployment.log`
2. Run health checks (see Health Checks section)
3. Check GitHub issues: https://github.com/Gray3x0/awesome-n8n-templates/issues

---

**Last Updated**: 2025-12-30
**Script Version**: 2.0
**Tested On**: Ubuntu 24.04 Noble LTS + GTX 1060 6GB
