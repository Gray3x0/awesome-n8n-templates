# 🚀 AI Empire - Quick Start Guide

**Get your complete AI infrastructure running in 30 minutes**

---

## Prerequisites

- Ubuntu 24.04 LTS
- NVIDIA GPU (GTX 1060 6GB or better)
- 50GB+ free disk space
- Sudo access
- Internet connection

---

## Installation Steps

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/awesome-n8n-templates.git
cd awesome-n8n-templates/ai-empire
```

### 2. Run Deployment Script

```bash
sudo bash scripts/deploy_complete.sh
```

**This will take 15-30 minutes** and install:
- Ollama + DeepSeek R1-8B model
- PostgreSQL + Redis
- LiteLLM gateway
- n8n automation
- Fabric CLI + 300+ patterns
- Cloudflare manager
- Tailscale VPN
- Domain routing
- Monitoring stack

### 3. Configure Credentials

After installation, edit these files with your credentials:

```bash
# Cloudflare API
nano cloudflare-manager/env.sh
# Add: CLOUDFLARE_API_TOKEN, CLOUDFLARE_ZONE_ID, DOMAIN_NAME

# Database
nano domain-manager/env.sh
# Change: DB_PASSWORD

# Tailscale
nano tailscale-manager/env.sh
# Add: TAILSCALE_API_KEY
```

### 4. Authenticate Tailscale

```bash
sudo tailscale up
# Follow the link to authenticate
```

### 5. Verify Installation

```bash
./scripts/manage.sh status
```

**Expected output:**
```
AI EMPIRE STATUS
================

SERVICES:
✓ Ollama
✓ Redis
✓ n8n
✓ PostgreSQL
✓ LiteLLM
✓ Cloudflare Daemon
✓ Domain Manager

GPU STATUS:
  Temp: 45°C | VRAM: 1200MB/6144MB (19%)
```

---

## Quick Tests

### Test Ollama

```bash
curl http://localhost:11434/api/tags
```

### Test Fabric

```bash
echo "AI is amazing" | fabric --pattern summarize
```

### Test LiteLLM

```bash
curl http://localhost:4000/health
```

### Test n8n

Open: http://localhost:5678

---

## First Workflow

### Create Content Extraction Pipeline

1. Open n8n: http://localhost:5678
2. Create new workflow
3. Add "Execute Command" node:
   ```bash
   echo "{{$json.content}}" | fabric --pattern extract_wisdom
   ```
4. Test with sample content
5. See it route to DeepSeek R1-8B (free!) when VRAM available

---

## Common Commands

```bash
# Check status
./scripts/manage.sh status

# Monitor real-time
./scripts/manage.sh monitor

# View logs
./scripts/manage.sh logs ollama

# Register new service
./scripts/manage.sh register-service api myapp 3000

# Sync DNS
./scripts/manage.sh dns-sync

# Renew SSL
./scripts/manage.sh ssl-renew
```

---

## Accessing Services

| Service | URL | Purpose |
|---------|-----|---------|
| n8n | http://localhost:5678 | Workflow automation |
| LiteLLM | http://localhost:4000 | API gateway |
| Grafana | http://localhost:3004 | Monitoring |
| Langfuse | http://localhost:3003 | LLM traces |

---

## Cost Savings

**Before AI Empire:** $765/month (Claude-only)
**After AI Empire:** $60-80/month (95% savings!)

**How?**
- Local DeepSeek handles 80% of requests (FREE)
- Redis caches responses (FREE)
- Claude only for complex reasoning ($20-30/month)
- Infrastructure costs: $40-50/month

---

## Next Steps

1. ✅ Configure Cloudflare DNS automation
2. ✅ Setup custom domains
3. ✅ Create n8n workflows with Fabric
4. ✅ Enable fine-tuning pipeline
5. ✅ Add monitoring dashboards
6. ✅ Configure backups

---

## Troubleshooting

### Ollama not starting

```bash
sudo systemctl restart ollama
sudo journalctl -u ollama -n 50
```

### Fabric not found

```bash
# Reinstall Fabric
go install github.com/danielmiessler/fabric@latest
export PATH=$PATH:$HOME/go/bin
```

### GPU issues

```bash
# Check GPU
nvidia-smi

# Check NVIDIA drivers
nvidia-smi --version
```

### Port conflicts

```bash
# Check what's using a port
sudo lsof -i:11434

# Kill process
sudo kill -9 <PID>
```

---

## Support

- 📖 Full documentation: [README.md](README.md)
- 🐛 Issues: GitHub Issues
- 💬 Discussion: GitHub Discussions

---

## Success Checklist

After installation, verify:

```
[ ] Ollama responding at :11434
[ ] LiteLLM at :4000
[ ] n8n at :5678
[ ] Fabric CLI working
[ ] GPU detected
[ ] PostgreSQL running
[ ] Redis running
[ ] Tailscale authenticated
```

---

**🎉 Congratulations! Your AI Empire is ready!**

Start building workflows, cutting costs, and enjoying local AI inference! 🚀
