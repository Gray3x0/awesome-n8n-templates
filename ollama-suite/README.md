# 🚀 Ultimate Ollama Enhancement Suite

**Complete auto-deployment system for local AI on GTX 1060 6GB / Ubuntu 24.04 LTS**

This comprehensive suite provides everything you need for cutting-edge local LLM deployment with 60+ tools, optimization, monitoring, security, and automation capabilities.

---

## 📋 Table of Contents

- [Features](#features)
- [Quick Start](#quick-start)
- [Components](#components)
- [Installation](#installation)
- [Usage](#usage)
- [Performance Optimization](#performance-optimization)
- [Security](#security)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)
- [Backup & Restore](#backup--restore)

---

## ✨ Features

### 🎯 Core Capabilities
- ✅ **Fully Optimized for GTX 1060 6GB** - KV cache quantization, Flash Attention, memory management
- ✅ **60+ Integrated Tools** - UI frontends, RAG systems, agent frameworks, monitoring, security
- ✅ **One-Command Installation** - Interactive menu-driven installer
- ✅ **Docker Compose Mega-Stack** - Deploy everything with `docker compose up`
- ✅ **Production-Ready Security** - LLM Guard, Nginx reverse proxy, Fail2ban, Tailscale support
- ✅ **Complete Observability** - Langfuse tracing, Prometheus metrics, Grafana dashboards
- ✅ **Automated Backups** - Full backup/restore with compression

### 🛠️ Included Components

#### UI Frontends
- **Open WebUI** - Feature-rich ChatGPT-like interface
- **LibreChat** - Multi-provider chat interface
- **AnythingLLM** - Enterprise RAG with document management
- **Chatbot UI** - Minimalist fast interface

#### RAG Systems
- **PrivateGPT** - Privacy-first document Q&A
- **LlamaIndex** - Advanced RAG framework
- **Qdrant** - High-performance vector database
- **Langflow** - Visual RAG workflow builder
- **ChromaDB** - Simple vector storage

#### Agent Frameworks
- **CrewAI** - Multi-agent orchestration
- **LangChain** - Chains and memory
- **LangGraph** - Stateful workflows with graph logic
- **AutoGPT** - Autonomous agents
- **Semantic Kernel** - Microsoft's agent SDK
- **Phidata** - Multi-modal agents

#### Performance Tools
- **llama.cpp** - Fastest CPU/GPU inference
- **ExLlamaV2** - Optimized CUDA kernels for EXL2 models
- **Benchmarking Suite** - Speed, context, quality tests
- **VRAM Calculator** - Model fit estimation

#### Monitoring & Observability
- **Langfuse** - LLM request tracing and analytics
- **Prometheus** - Metrics collection
- **Grafana** - Dashboards and visualization
- **Ollama Exporter** - Custom Ollama metrics

#### Security
- **LLM Guard** - Prompt injection prevention, PII detection
- **Nginx** - Reverse proxy with rate limiting
- **Fail2ban** - Intrusion prevention
- **UFW** - Firewall configuration
- **SSL/TLS** - HTTPS support

#### Integration Tools
- **n8n** - Workflow automation
- **Flowise** - Visual LLM app builder
- **Dify** - LLM application platform
- **Fabric** - 300+ AI prompt patterns CLI
- **AIChat** - All-in-one terminal AI
- **Continue.dev** - VSCode AI coding assistant
- **LiteLLM** - Universal API gateway

#### Voice Integration
- **Whisper** - Speech-to-text
- **Piper TTS** - Text-to-speech
- **Voice Assistant** - Complete voice interaction system

---

## 🚀 Quick Start

### 1. Remove Existing Ollama (Optional)

```bash
cd ~/awesome-n8n-templates/ollama-suite
chmod +x uninstall-ollama.sh
./uninstall-ollama.sh
```

### 2. Install Everything

```bash
chmod +x install-ollama-suite.sh
./install-ollama-suite.sh
```

The installer will guide you through:
- ✅ Prerequisite checking (Docker, NVIDIA drivers, Python, Node.js)
- ✅ Component selection (pick what you need)
- ✅ Automatic installation and configuration
- ✅ Service setup and startup

### 3. Deploy Docker Stack (Alternative)

```bash
cd ~/ollama-suite
docker compose up -d
```

### 4. Access Services

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| Ollama API | http://localhost:11434 | - |
| Open WebUI | http://localhost:3000 | No auth by default |
| LibreChat | http://localhost:3001 | Register on first visit |
| AnythingLLM | http://localhost:3002 | Set on first visit |
| Langfuse | http://localhost:3003 | Create on first visit |
| Grafana | http://localhost:3004 | admin / admin |
| Flowise | http://localhost:3005 | admin / admin |
| n8n | http://localhost:5678 | Set on first visit |
| Qdrant | http://localhost:6333 | - |
| Prometheus | http://localhost:9090 | - |

---

## 📦 Installation Options

### Option 1: Interactive Installation

```bash
./install-ollama-suite.sh
```

**Menu Options:**
1. **Core Installation** - Ollama + GTX 1060 optimizations + models (Required)
2. **UI Frontends** - Open WebUI, LibreChat, AnythingLLM
3. **RAG Systems** - PrivateGPT, LlamaIndex, Qdrant, Langflow
4. **Agent Frameworks** - CrewAI, LangChain, AutoGPT
5. **Performance Tools** - ExLlamaV2, llama.cpp, benchmarks
6. **Monitoring** - Langfuse, Prometheus, Grafana
7. **Security** - LLM Guard, Nginx, Fail2ban
8. **Integrations** - Continue.dev, Fabric, n8n, Flowise
9. **Voice** - Whisper, Piper TTS, voice assistant
10. **Install ALL** - Complete mega-stack

### Option 2: Individual Module Installation

```bash
# Install specific modules
source scripts/install-ui-frontends.sh && install_ui_frontends
source scripts/install-rag-systems.sh && install_rag_systems
source scripts/install-agent-frameworks.sh && install_agent_frameworks
source scripts/install-monitoring.sh && install_monitoring
source scripts/install-security.sh && install_security
source scripts/install-integrations.sh && install_integrations
source scripts/install-voice.sh && install_voice
source scripts/install-performance-tools.sh && install_performance_tools
```

### Option 3: Docker Compose Only

```bash
cd ~/ollama-suite
docker compose up -d
```

---

## 🎯 Usage Examples

### Basic Ollama Usage

```bash
# List installed models
ollama list

# Run a model
ollama run llama3.2:3b "What is machine learning?"

# Pull a new model
ollama pull qwen2.5:7b

# Check Ollama status
systemctl status ollama

# View logs
sudo journalctl -u ollama -f
```

### RAG with LlamaIndex

```python
cd ~/ollama-suite/projects
python llamaindex_rag_example.py /path/to/documents
```

### Multi-Agent with CrewAI

```python
cd ~/ollama-suite/projects
python crewai_example.py "Research quantum computing applications"
```

### Voice Assistant

```python
# Interactive text mode
cd ~/ollama-suite/projects
python voice_assistant.py

# Voice mode (with audio file)
./record_audio.sh my_audio.wav
python voice_assistant.py my_audio.wav
```

### Benchmark Models

```python
cd ~/ollama-suite/projects
python ollama_benchmark.py deepseek-r1:7b
```

### CLI Tools

```bash
# Fabric - AI prompt patterns
echo "Long article text..." | fabric --pattern summarize

# AIChat - Terminal AI
aichat "Explain Docker containers"
aichat --session work "What were we discussing?"
```

---

## ⚡ Performance Optimization

### GTX 1060 6GB Best Practices

1. **Use Q4_K_M quantization** - Best balance of quality and VRAM
2. **Enable KV cache quantization** - Already configured (`q8_0`)
3. **Limit context length** - 4096 tokens for 7B models
4. **Load one model at a time** - Already configured
5. **Use smaller models for speed** - llama3.2:3b for fast responses

### Recommended Models

```bash
# Speed optimized (2-3GB VRAM)
ollama pull llama3.2:3b
ollama pull phi3:mini

# Quality optimized (4-5GB VRAM)
ollama pull deepseek-r1:7b
ollama pull qwen2.5:7b

# Embeddings (275MB)
ollama pull nomic-embed-text

# Code (2GB)
ollama pull starcoder2:3b
```

### Performance Monitoring

```bash
# Real-time GPU monitoring
nvidia-smi -l 1

# Ollama metrics
curl http://localhost:8000/metrics

# Check VRAM requirements
cd ~/ollama-suite/projects
python vram_calculator.py
```

### Expected Performance

| Model | Quantization | Context | VRAM | Tokens/sec |
|-------|--------------|---------|------|------------|
| Llama 3.2 3B | Q4_K_M | 8K | ~2.5GB | 35-45 |
| Qwen 2.5 7B | Q4_K_M | 4K | ~4.1GB | 18-25 |
| DeepSeek R1 7B | Q4_K_M | 4K | ~4.5GB | 15-22 |

---

## 🔒 Security

### Security Features Enabled

- ✅ **LLM Guard** - Prompt injection detection, PII anonymization, toxicity filtering
- ✅ **Nginx Reverse Proxy** - Rate limiting, SSL/TLS, access control
- ✅ **Fail2ban** - Automated IP blocking for suspicious activity
- ✅ **UFW Firewall** - Network access control
- ✅ **Tailscale Support** - Secure remote access without port forwarding

### Security Best Practices

```bash
# Check security status
sudo systemctl status nginx
sudo fail2ban-client status ollama
sudo ufw status

# Test LLM Guard
cd ~/ollama-suite/projects
python llm_guard_middleware.py

# Review security checklist
cat ~/ollama-suite/configs/security/SECURITY_CHECKLIST.md
```

### Tailscale Configuration

1. Install Tailscale: `curl -fsSL https://tailscale.com/install.sh | sh`
2. Connect: `sudo tailscale up`
3. Apply ACLs from: `~/ollama-suite/configs/security/tailscale-acl.json`

---

## 📊 Monitoring

### Access Monitoring Dashboards

- **Grafana**: http://localhost:3004 (admin/admin)
- **Prometheus**: http://localhost:9090
- **Langfuse**: http://localhost:3003

### Monitor Ollama

```bash
# System metrics
docker logs prometheus
docker logs grafana

# Ollama traces
# Configure Langfuse in your application
# See: ~/ollama-suite/projects/langfuse_example.py

# GPU metrics
docker logs nvidia-exporter
```

### Custom Metrics

```python
# Integrate Langfuse in your app
from langfuse import Langfuse
langfuse = Langfuse(
    public_key="...",
    secret_key="...",
    host="http://localhost:3003"
)
```

---

## 🛠️ Troubleshooting

### Ollama Issues

```bash
# Ollama not responding
sudo systemctl restart ollama
sudo journalctl -u ollama -n 100

# Out of VRAM
# - Use smaller model (3B instead of 7B)
# - Reduce context length
# - Check for other GPU processes: nvidia-smi
```

### Docker Issues

```bash
# Services won't start
cd ~/ollama-suite
docker compose down
docker compose up -d

# View logs
docker logs <service-name>

# Restart specific service
docker compose restart open-webui
```

### Network Issues

```bash
# Check ports
sudo netstat -tulpn | grep LISTEN

# Test Ollama API
curl http://localhost:11434/api/tags

# Check Docker network
docker network inspect ollama-network
```

### Common Fixes

| Problem | Solution |
|---------|----------|
| "Out of VRAM" | Use smaller model or reduce context |
| "Connection refused" | Check service status: `docker ps` |
| "Model not found" | Pull model: `ollama pull <model>` |
| Slow inference | Check GPU usage: `nvidia-smi` |
| Can't access UI | Check port binding: `netstat -tulpn` |

---

## 💾 Backup & Restore

### Create Backup

```bash
cd ~/ollama-suite
./scripts/backup.sh
```

**Backs up:**
- Ollama models and configuration
- All data directories
- Docker volumes
- User configurations
- Project files

**Backup location:** `~/ollama-suite/backups/`

### Restore from Backup

```bash
# Extract backup
tar -xzf ollama-backup-YYYYMMDD_HHMMSS.tar.gz
cd ollama-backup-YYYYMMDD_HHMMSS

# Run restore
./restore.sh
```

### Automatic Backups

```bash
# Add to crontab for daily backups at 2 AM
crontab -e

# Add line:
0 2 * * * /home/user/ollama-suite/scripts/backup.sh
```

---

## 🔄 Updates

### Update All Components

```bash
cd ~/ollama-suite
./scripts/update-all.sh
```

**Updates:**
- Ollama binary
- Docker images
- Python packages
- Git repositories
- Fabric patterns
- llama.cpp rebuild

### Manual Updates

```bash
# Update Ollama only
curl -fsSL https://ollama.com/install.sh | sh

# Update Docker images
cd ~/ollama-suite
docker compose pull
docker compose up -d

# Update specific package
pip install --upgrade llama-index
```

---

## 📚 Documentation

### Component Documentation

- **Ollama**: https://ollama.com/docs
- **Open WebUI**: https://docs.openwebui.com
- **LangChain**: https://python.langchain.com
- **CrewAI**: https://docs.crewai.com
- **Qdrant**: https://qdrant.tech/documentation
- **Langfuse**: https://langfuse.com/docs

### Configuration Files

```
~/ollama-suite/
├── configs/
│   ├── prometheus.yml        # Prometheus scrape config
│   ├── security/              # Security templates
│   └── grafana/               # Grafana provisioning
├── scripts/                   # All installation scripts
├── projects/                  # Example projects
├── data/                      # Application data
├── logs/                      # Log files
└── backups/                   # Backup files
```

---

## 🎓 Advanced Usage

### Custom Model Fine-tuning

See: `~/ollama-suite/projects/Auto-GPT/` for AutoGPT integration
See: Axolotl documentation in agent frameworks module

### API Integration

```python
# OpenAI-compatible API via LiteLLM
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:4000",
    api_key="sk-1234"
)

response = client.chat.completions.create(
    model="deepseek-r1",
    messages=[{"role": "user", "content": "Hello!"}]
)
```

### VSCode Integration

1. Install Continue.dev extension
2. Configuration already created at: `~/.continue/config.json`
3. Start coding with AI assistance!

---

## 🤝 Support

### Getting Help

1. Check troubleshooting section above
2. Review component documentation
3. Check installation logs: `~/ollama-suite/logs/`
4. Review service logs: `docker logs <service>`

### Reporting Issues

Create detailed bug report with:
- System info: `nvidia-smi`, `docker --version`, `ollama --version`
- Error logs
- Steps to reproduce

---

## 📝 License

This suite integrates many open-source projects, each with their own licenses. Please review individual component licenses.

---

## 🌟 Credits

Built by combining cutting-edge projects:
- Ollama by Ollama Inc.
- Open WebUI, LibreChat, AnythingLLM communities
- LangChain, CrewAI, LlamaIndex teams
- Qdrant, Langfuse, and many more amazing OSS projects

---

## 🚀 Next Steps

1. ✅ Install the suite
2. ✅ Pull your first models
3. ✅ Access Open WebUI
4. ✅ Try RAG with your documents
5. ✅ Experiment with agents
6. ✅ Set up monitoring
7. ✅ Configure backups
8. ✅ Secure with Tailscale

**Enjoy your cutting-edge local AI deployment! 🎉**
