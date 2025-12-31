# ⚡ Quick Start - Simplified Setup

## 🎯 Goal: Claude Pro API + Local DeepSeek + Knowledge Base

**Time to complete:** 10 minutes
**Monthly cost after optimization:** $50-75 (saves $175-200/month)

---

## 🚀 Get Started in 3 Steps

### Step 1: Install Ollama + DeepSeek (5 minutes)

```bash
cd ~/awesome-n8n-templates/ollama-suite
chmod +x install-ollama-suite.sh
./install-ollama-suite.sh
```

When prompted, select **[1] Core Installation**

This installs:
- ✅ Ollama optimized for GTX 1060 6GB
- ✅ DeepSeek-R1:7b model (free, local)
- ✅ KV cache quantization (saves 20-30% VRAM)
- ✅ Flash Attention (faster inference)

**Download time:** ~5-10 minutes (DeepSeek model is ~4.5GB)

---

### Step 2: Start Qdrant for Knowledge Base (1 minute)

```bash
cd ~/awesome-n8n-templates/ollama-suite
docker compose up -d qdrant
```

This starts your vector database for storing downloaded docs locally.

---

### Step 3: Get Claude Pro API Key (2 minutes)

1. Go to https://console.anthropic.com/
2. Sign in with your Claude Pro account
3. Click "API Keys" → "Create Key"
4. Copy the key (starts with `sk-ant-...`)
5. Add to your n8n AI Agent node

---

## ✅ Verify Everything Works

```bash
# Test local DeepSeek
ollama run deepseek-r1:7b "What is 2+2?"

# Test Qdrant
curl http://localhost:6333

# Check GPU usage
nvidia-smi
```

**Expected output:**
- DeepSeek responds with answer (~60-80 tokens/sec)
- Qdrant returns JSON response
- GPU shows ~4.5GB VRAM used

---

## 🎉 You're Done!

**You now have:**
- ✅ Free local AI (DeepSeek-R1:7b)
- ✅ Claude Pro API access
- ✅ Vector database (Qdrant)
- ✅ Optimized for GTX 1060 6GB

---

## 💰 Next: Save Money with Smart Routing

### Create n8n Workflow (10 minutes)

**Simple routing logic:**

```
Trigger: Webhook
↓
IF node: Check question complexity
├─ Simple (< 50 chars) → HTTP Request to DeepSeek (FREE)
└─ Complex → AI Agent to Claude (costs money)
↓
Return response
```

**n8n nodes to add:**
1. **Webhook** trigger
2. **IF** node - condition: `{{$json.question.length}} < 50`
3. **HTTP Request** node (DeepSeek):
   - URL: `http://localhost:11434/api/generate`
   - Method: POST
   - Body:
   ```json
   {
     "model": "deepseek-r1:7b",
     "prompt": "{{$json.question}}",
     "stream": false
   }
   ```
4. **AI Agent** node (Claude):
   - Provider: Anthropic
   - API Key: `sk-ant-...`
   - Model: `claude-sonnet-4`

**Result:** 30-40% of questions go to free DeepSeek, saving $75-100/month

---

## 📚 Next: Build Knowledge Base (30 minutes)

### Setup Web Scraping

```bash
# Install tools
pip install requests beautifulsoup4 pypdf2

# Create directory
mkdir -p ~/knowledge-base/{docs,pdfs}
```

### Create n8n Doc Downloader Workflow

```
Schedule: Daily 2 AM
↓
HTTP Request: Fetch RSS feed (Anthropic blog)
↓
Loop through new articles
↓
HTTP Request: Download article
↓
Extract text
↓
PostgreSQL: Store full text (your existing DB)
↓
Ollama: Generate embedding with DeepSeek
↓
Qdrant: Store vector
```

**Result:** Questions check local docs first (free), API only if not found

---

## 🔥 Performance Tips

### Best Models for GTX 1060 6GB

```bash
# Primary (already installed)
ollama list  # Should show deepseek-r1:7b

# Optional: Faster but less capable
ollama pull llama3.2:3b  # 35-45 tokens/sec, only 2.5GB VRAM

# Embeddings (for knowledge base)
ollama pull nomic-embed-text  # 275MB, generates vectors for Qdrant
```

### Monitor Your System

```bash
# Watch GPU usage
nvidia-smi -l 1

# Check Ollama status
systemctl status ollama

# View logs
sudo journalctl -u ollama -f

# Check Qdrant
curl http://localhost:6333/collections
```

---

## 💰 Cost Tracking

**Before optimization:**
- 50,000 questions/month × $0.005 = **$250/month**

**After smart routing (30% local):**
- 35,000 to Claude × $0.003 = **$105/month**
- Savings: **$145/month = $1,740/year**

**After prompt caching (90% savings on cached):**
- **$50-75/month**
- Savings: **$175-200/month = $2,100-2,400/year**

---

## 🛠️ Troubleshooting

### "Out of VRAM"
```bash
# Use smaller model
ollama pull llama3.2:3b
ollama run llama3.2:3b
```

### "Connection refused" (Ollama)
```bash
sudo systemctl restart ollama
sudo journalctl -u ollama -n 50
```

### "Qdrant not responding"
```bash
docker ps | grep qdrant
docker restart qdrant
```

---

## 📖 Learn More

- **Full documentation:** See README.md
- **Cost optimization:** Prompt caching, batch API
- **Knowledge base:** Auto-download and index docs
- **n8n workflows:** Smart routing examples

---

## ✨ Summary

You're set up for maximum savings:

1. ✅ **Local AI** - DeepSeek-R1 (free, 60-80 t/s)
2. ✅ **Cloud API** - Claude Pro (complex tasks only)
3. ✅ **Vector DB** - Qdrant (local knowledge base)
4. ✅ **Optimized** - GTX 1060 6GB config applied

**Next actions:**
- Create smart routing workflow in n8n
- Enable prompt caching on Claude calls
- Start building local knowledge base
- Track your savings!

**You're optimized! 🚀**
