# ⚡ Quick Start Guide

## 🚀 Get Up and Running in 5 Minutes

### Step 1: Remove Old Ollama (if exists)

```bash
cd ~/awesome-n8n-templates/ollama-suite
./uninstall-ollama.sh
```

### Step 2: Run the Installer

```bash
./install-ollama-suite.sh
```

**What happens:**
1. ✅ Checks prerequisites (Docker, NVIDIA drivers, Python, Node.js)
2. ✅ Installs missing components automatically
3. ✅ Shows interactive menu
4. ✅ Installs your selected components
5. ✅ Configures everything for GTX 1060 6GB

### Step 3: Choose Components

**Recommended for first-time users:**

Select option **[1]** - Core Installation
- Installs Ollama with GTX 1060 optimizations
- Downloads recommended models (deepseek-r1:7b, llama3.2:3b, etc.)
- Takes ~10-15 minutes depending on internet speed

Then select option **[2]** - UI Frontends
- Installs Open WebUI (ChatGPT-like interface)
- Takes ~2 minutes

**Or select [A]** to install EVERYTHING! ⚡

### Step 4: Access Your AI

Open your browser:
- **http://localhost:3000** - Open WebUI (recommended)
- **http://localhost:11434** - Ollama API

### Step 5: Start Chatting!

In Open WebUI:
1. Select a model from dropdown
2. Start typing your question
3. Get AI-powered responses!

---

## 🎯 Quick Commands

```bash
# List installed models
ollama list

# Chat with a model (terminal)
ollama run llama3.2:3b "Explain Docker"

# Check what's running
docker ps

# View Ollama logs
sudo journalctl -u ollama -f

# Restart everything
cd ~/ollama-suite && docker compose restart
```

---

## 🔥 Quick Tips for GTX 1060 6GB

1. **Use llama3.2:3b for speed** (~40 tokens/sec)
2. **Use deepseek-r1:7b for quality** (~20 tokens/sec)
3. **Don't load multiple 7B models** - Switch between them
4. **Monitor VRAM:** `nvidia-smi -l 1`

---

## 🛠️ Troubleshooting

### Ollama not starting?
```bash
sudo systemctl status ollama
sudo systemctl restart ollama
```

### Out of VRAM?
```bash
# Use smaller model
ollama pull llama3.2:3b
ollama run llama3.2:3b
```

### Can't access Open WebUI?
```bash
docker ps  # Check if running
docker logs open-webui  # Check logs
docker restart open-webui  # Restart
```

---

## 📚 Next Steps

1. ✅ Explore other UI frontends (LibreChat, AnythingLLM)
2. ✅ Try RAG with your documents (install option [3])
3. ✅ Set up monitoring (install option [6])
4. ✅ Install integrations (Fabric CLI, n8n automation)
5. ✅ Read full README.md for advanced features

---

## 💡 Pro Tips

**Best models for your hardware:**
```bash
ollama pull llama3.2:3b        # Fast (35-45 t/s)
ollama pull deepseek-r1:7b      # Quality reasoning (15-22 t/s)
ollama pull qwen2.5:7b          # Function calling (18-25 t/s)
ollama pull nomic-embed-text    # Embeddings (275MB)
ollama pull starcoder2:3b       # Code completion (2GB)
```

**Speed up inference:**
- KV cache quantization is already enabled! ✅
- Flash Attention is already enabled! ✅
- Limit to one model loaded at a time ✅

**Save VRAM:**
- Close browser tabs when not needed
- Don't run multiple UIs simultaneously
- Use Q4_K_M or smaller quantizations

---

## 🎉 You're All Set!

Enjoy your cutting-edge local AI deployment optimized for GTX 1060 6GB!

Need help? Check **README.md** for comprehensive documentation.

---

**Made with ❤️ for local AI enthusiasts**
