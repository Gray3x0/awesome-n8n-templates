# 🚀 Usage Guide - Enhanced Ollama Suite

## ✅ Your installation now has COMPLETE cleanup!

### **Step 1: Nuclear Uninstall (removes EVERYTHING)**

```bash
cd /raid/awesome-n8n-templates/ollama-suite
./uninstall-ollama.sh
```

**This will:**
- ✅ Kill all processes on port 11434
- ✅ Stop ALL systemd services
- ✅ Remove ALL Docker containers with "ollama"
- ✅ Scan and stop Docker Compose stacks (n8n, mcp, etc.)
- ✅ Remove ALL Ollama Docker images and volumes
- ✅ Delete ALL binaries from /usr/local/bin, /usr/bin, etc.
- ✅ Remove ALL data directories (9+ locations checked)
- ✅ Clean environment variables from all shells
- ✅ Remove Python packages
- ✅ Verify port 11434 is free
- ✅ Final force-kill any remaining processes

### **Step 2: Fresh Installation**

```bash
./install-ollama-suite.sh
```

Select option **[A]** for complete installation or pick individual components.

### **Step 3: Verify Installation**

```bash
./scripts/verify-installation.sh
```

**This checks:**
- ✅ Ollama binary and service status
- ✅ GTX 1060 optimizations (KV cache q8_0, Flash Attention)
- ✅ GPU detection and VRAM
- ✅ Port 11434 availability and API response
- ✅ All required directories and permissions
- ✅ Docker and NVIDIA runtime
- ✅ Python packages
- ✅ Installed models
- ✅ Basic inference test

**Output example:**
```
╔════════════════════════════════════════════════════════════╗
║  Ollama Installation
╚════════════════════════════════════════════════════════════╝

[✓ PASS] Ollama binary found: ollama version 0.5.0
[✓ PASS] Ollama binary exists at /usr/local/bin/ollama

╔════════════════════════════════════════════════════════════╗
║  Ollama Service
╚════════════════════════════════════════════════════════════╝

[✓ PASS] Ollama service is running
[✓ PASS] Ollama service is enabled (will start on boot)
[✓ PASS] GTX 1060 optimization config found
[✓ PASS]   KV cache quantization enabled (q8_0)
[✓ PASS]   Flash Attention enabled
[✓ PASS]   Single model loading enforced (prevents OOM)

...

╔══════════════════════════════════════════════════════════════════╗
║                     VERIFICATION SUMMARY                         ║
╚══════════════════════════════════════════════════════════════════╝

[✓ PASS] ALL CHECKS PASSED! ✨

Your Ollama installation is perfect and ready to use!
```

---

## 🔧 Troubleshooting Workflow

### **Problem: Port 11434 still in use**

```bash
# Check what's using it
sudo lsof -i:11434

# Force kill everything
sudo lsof -ti:11434 | xargs -r sudo kill -9

# Run uninstall again
./uninstall-ollama.sh
```

### **Problem: Ollama service won't start**

```bash
# Check logs
sudo journalctl -u ollama -n 50

# Verify configuration
cat /etc/systemd/system/ollama.service.d/override.conf

# Restart service
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

### **Problem: Out of VRAM**

```bash
# Use smaller model
ollama pull llama3.2:3b  # Only 2.5GB VRAM

# Or reduce context in config
sudo nano /etc/systemd/system/ollama.service.d/override.conf
# Add: Environment="OLLAMA_NUM_CTX=2048"
```

### **Problem: Docker containers interfere**

```bash
# The uninstall script now automatically handles this!
# But if needed manually:
docker ps -a | grep ollama
docker stop <container_id>
docker rm <container_id>
```

---

## 📋 Complete Installation Workflow

```bash
# 1. Clean slate
cd /raid/awesome-n8n-templates/ollama-suite
./uninstall-ollama.sh

# 2. Fresh install
./install-ollama-suite.sh
# Select: [A] Install ALL Components

# 3. Verify everything
./scripts/verify-installation.sh

# 4. Test
ollama pull llama3.2:3b
ollama run llama3.2:3b "Hello!"

# 5. Access UIs
# Open WebUI: http://localhost:3000
# LibreChat: http://localhost:3001
# Grafana: http://localhost:3004
```

---

## 🎯 What's New

### **Enhanced Uninstall Script**
- **20 comprehensive steps** to remove everything
- Scans **7 common locations** for docker-compose files
- Checks **9 data directories** for Ollama
- Verifies port 11434 is free before finishing
- Force-kills stubborn processes
- Provides detailed summary

### **Post-Install Verification**
- **10 verification sections** covering all aspects
- Checks **GTX 1060 optimizations** are applied
- Tests **basic inference** functionality
- Verifies **GPU access** and VRAM
- Checks **Docker NVIDIA runtime**
- **Color-coded output** (Pass/Fail/Warn)
- Provides **actionable suggestions** for issues

---

## 🚀 Pro Tips

**1. Always verify after install:**
```bash
./scripts/verify-installation.sh
```

**2. If port issues persist:**
```bash
# Check for hidden processes
ps aux | grep ollama
sudo netstat -tulpn | grep 11434
```

**3. Monitor during operation:**
```bash
# Watch GPU usage
nvidia-smi -l 1

# Watch Ollama logs
sudo journalctl -u ollama -f

# Check Docker containers
docker ps
```

**4. Quick health check:**
```bash
# Should return JSON with models
curl http://localhost:11434/api/tags
```

---

## 📝 Quick Reference

| Command | Purpose |
|---------|---------|
| `./uninstall-ollama.sh` | Nuclear removal of everything |
| `./install-ollama-suite.sh` | Interactive installer |
| `./scripts/verify-installation.sh` | Post-install verification |
| `./scripts/backup.sh` | Backup everything |
| `./scripts/update-all.sh` | Update all components |
| `ollama list` | List installed models |
| `ollama pull <model>` | Download a model |
| `ollama run <model>` | Test a model |
| `docker ps` | Check running containers |
| `sudo systemctl status ollama` | Check Ollama service |

---

## ✨ You're All Set!

The enhanced scripts ensure:
- ✅ **Complete cleanup** - no remnants from old installations
- ✅ **Proper verification** - all components checked
- ✅ **GTX 1060 optimized** - maximum performance for your hardware
- ✅ **Ready to use** - everything configured and tested

Enjoy your cutting-edge local AI deployment! 🎉
