# 💰 Cost Optimization Guide - Claude Pro + Local AI

**Goal:** Reduce Claude API costs from $250/month to $50-75/month

**Savings:** $2,100-2,400/year

---

## 📊 Current Cost Reality

**Without optimization (all questions to Claude):**
```
50,000 questions/month × $0.005 avg = $250/month = $3,000/year
```

**With full optimization:**
```
50,000 questions/month × $0.001 avg = $50-75/month = $600-900/year
Savings: $2,100-2,400/year
```

---

## 🎯 Strategy 1: Smart Routing (Save 30-40%)

### Concept
Route simple questions to free local DeepSeek, complex questions to paid Claude.

### Implementation in n8n

**Workflow:**
```
Webhook Trigger
↓
IF Node: Determine complexity
├─ Simple → DeepSeek (FREE)
└─ Complex → Claude ($$$)
```

### Complexity Detection Logic

```javascript
// In n8n IF node, add condition:

// Method 1: Question length
{{$json.question.length}} < 50

// Method 2: Keywords
{{$json.question.toLowerCase().includes('summarize')}} ||
{{$json.question.toLowerCase().includes('translate')}} ||
{{$json.question.toLowerCase().includes('what is')}}

// Method 3: Custom classifier (more advanced)
// Train a small model to classify "simple" vs "complex"
```

### n8n Node Configuration

**1. Webhook Node:**
- HTTP Method: POST
- Path: /ask
- Body expects: `{"question": "Your question here"}`

**2. IF Node (Complexity Check):**
- Condition: `{{$json.question.length}} < 50`
- True branch → DeepSeek
- False branch → Claude

**3. HTTP Request Node (DeepSeek - FREE):**
```json
{
  "url": "http://localhost:11434/api/generate",
  "method": "POST",
  "body": {
    "model": "deepseek-r1:7b",
    "prompt": "{{$json.question}}",
    "stream": false
  }
}
```

**4. AI Agent Node (Claude - PAID):**
- Provider: Anthropic
- API Key: `sk-ant-...`
- Model: `claude-sonnet-4`
- Prompt: `{{$json.question}}`

### Expected Routing Distribution

```
Simple questions (30-40%):
- "What is 2+2?"
- "Translate 'hello' to Spanish"
- "Summarize: [short text]"
→ DeepSeek (FREE)

Complex questions (60-70%):
- "Analyze this legal contract and identify risks"
- "Write a detailed business plan for..."
- "Compare multiple options with pros/cons"
→ Claude (PAID)
```

### Cost Impact

**Before:**
- 50,000 questions × $0.005 = **$250/month**

**After smart routing:**
- 35,000 to Claude × $0.003 = **$105/month**
- 15,000 to DeepSeek = **$0** (local)
- **Total: $105/month**
- **Savings: $145/month = $1,740/year**

---

## 🎯 Strategy 2: Prompt Caching (Save 90% on Cached Tokens)

### Concept
Cache system prompts and repeated content. First call pays full price, subsequent calls pay 90% less.

### What to Cache

**Good candidates:**
- System prompts (therapist persona, legal expert, etc.)
- Large documents (legal contracts, manuals)
- Conversation history
- Knowledge base context

**Bad candidates:**
- User questions (always unique)
- Short prompts (< 1000 tokens)

### Implementation in n8n

**HTTP Request Node (Claude API with caching):**

```json
{
  "url": "https://api.anthropic.com/v1/messages",
  "method": "POST",
  "headers": {
    "x-api-key": "{{$env.CLAUDE_API_KEY}}",
    "anthropic-version": "2023-06-01",
    "content-type": "application/json"
  },
  "body": {
    "model": "claude-sonnet-4",
    "max_tokens": 1024,
    "system": [
      {
        "type": "text",
        "text": "You are a legal expert specializing in contract law. Your responses should be thorough, cite relevant laws, and identify potential risks. [... 2000+ tokens of context ...]",
        "cache_control": {"type": "ephemeral"}
      }
    ],
    "messages": [
      {
        "role": "user",
        "content": "{{$json.question}}"
      }
    ]
  }
}
```

### Cost Impact

**Without caching:**
```
System prompt: 2000 tokens × $0.003/1K = $0.006 per call
50,000 calls = $300/month on system prompts alone
```

**With caching:**
```
First call: 2000 tokens × $0.003/1K = $0.006
Next 49,999 calls: 2000 tokens × $0.0003/1K = $0.0006 per call
Total: $0.006 + (49,999 × $0.0006) = $30.00
Savings: $270/month = $3,240/year
```

### Cache Behavior

- **Cache duration:** 5 minutes (can be longer with frequent use)
- **Cache key:** Based on exact text match
- **Automatic expiration:** After inactivity

---

## 🎯 Strategy 3: Local Knowledge Base (Save 70% on Repeated Questions)

### Concept
Search local docs first (free), only ask Claude if not found locally.

### Implementation Flow

```
User asks question
↓
1. Search PostgreSQL (full-text) → Found? Return (FREE)
2. Search Qdrant (semantic) → Found? Return (FREE)
3. Not found? → Ask Claude → Store answer locally
4. Next similar question → Return from local (FREE)
```

### n8n Workflow

**1. PostgreSQL Full-Text Search Node:**
```sql
SELECT content, title, url
FROM knowledge_base
WHERE to_tsvector('english', content) @@ plainto_tsquery('{{$json.question}}')
LIMIT 5;
```

**2. IF Node:**
- Condition: `{{$json.results.length}} > 0`
- True → Return local results (free)
- False → Continue to Qdrant

**3. Qdrant Semantic Search (HTTP Request):**
```json
{
  "url": "http://localhost:6333/collections/knowledge/points/search",
  "method": "POST",
  "body": {
    "vector": "{{$json.embedding}}",
    "limit": 5,
    "score_threshold": 0.7
  }
}
```

**4. IF Node:**
- Condition: `{{$json.result.length}} > 0`
- True → Return Qdrant results (free)
- False → Ask Claude (paid)

**5. Claude API Node (only if local search fails):**
- Ask Claude
- Store response in PostgreSQL + Qdrant
- Return answer

### Cost Impact

**Without local KB:**
```
50,000 questions × $0.003 = $150/month
```

**With local KB (70% answered locally):**
```
35,000 answered locally = $0
15,000 to Claude × $0.003 = $45/month
Savings: $105/month = $1,260/year
```

---

## 🎯 Strategy 4: Batch API (Save 50% on Non-Urgent Tasks)

### Concept
Use Claude's Batch API for non-urgent tasks (results in ~24 hours, costs 50% less).

### When to Use

**Good for:**
- Daily document summarization
- Weekly report generation
- Monthly data analysis
- Scheduled content generation

**Bad for:**
- Real-time chat
- User-facing Q&A
- Time-sensitive tasks

### Implementation in n8n

**1. Schedule Trigger:**
- Cron: `0 2 * * *` (daily at 2 AM)

**2. Aggregate Node:**
- Collect all pending batch tasks

**3. HTTP Request Node (Batch API):**
```json
{
  "url": "https://api.anthropic.com/v1/messages/batches",
  "method": "POST",
  "headers": {
    "x-api-key": "{{$env.CLAUDE_API_KEY}}",
    "anthropic-version": "2023-06-01",
    "content-type": "application/json"
  },
  "body": {
    "requests": [
      {
        "custom_id": "doc-1",
        "params": {
          "model": "claude-sonnet-4",
          "max_tokens": 1024,
          "messages": [{"role": "user", "content": "Summarize document 1"}]
        }
      },
      {
        "custom_id": "doc-2",
        "params": {
          "model": "claude-sonnet-4",
          "max_tokens": 1024,
          "messages": [{"role": "user", "content": "Summarize document 2"}]
        }
      }
    ]
  }
}
```

**4. Wait Node (24 hours):**
- Delay: 86400 seconds

**5. Retrieve Results:**
```json
{
  "url": "https://api.anthropic.com/v1/messages/batches/{{$json.batch_id}}/results",
  "method": "GET"
}
```

### Cost Impact

**Standard API:**
```
1,000 summaries/month × $0.003 = $30/month
```

**Batch API (50% discount):**
```
1,000 summaries/month × $0.0015 = $15/month
Savings: $15/month = $180/year
```

---

## 🎯 Full Optimization Stack

### Combined Strategies

**1. Smart Routing** (30% to DeepSeek)
**2. Prompt Caching** (90% savings on cached)
**3. Local Knowledge Base** (70% answered locally)
**4. Batch API** (50% off for scheduled tasks)

### Cost Breakdown

**Scenario: 50,000 questions/month**

```
Without optimization:
50,000 × $0.005 = $250/month

With full optimization:
├─ 15,000 simple → DeepSeek = $0 (30%)
├─ 20,000 from local KB → Free = $0 (40%)
├─ 10,000 to Claude (cached) → $5 (20%)
├─ 4,000 to Claude (new) → $40 (8%)
└─ 1,000 batch tasks → $1.50 (2%)

Total: $46.50/month
Savings: $203.50/month = $2,442/year
```

---

## 📊 Monitoring Your Savings

### Track in PostgreSQL

```sql
CREATE TABLE api_usage (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT NOW(),
    question TEXT,
    source VARCHAR(20),  -- 'deepseek', 'local', 'claude', 'batch'
    tokens_used INT,
    cost DECIMAL(10,4),
    cached BOOLEAN
);
```

### Monthly Report Query

```sql
SELECT
    source,
    COUNT(*) as requests,
    SUM(tokens_used) as total_tokens,
    SUM(cost) as total_cost
FROM api_usage
WHERE timestamp >= DATE_TRUNC('month', NOW())
GROUP BY source
ORDER BY total_cost DESC;
```

### n8n Dashboard

Create a workflow to:
1. Query usage stats daily
2. Generate cost report
3. Send email/Slack notification if costs exceed threshold

---

## 🎓 Best Practices

### 1. Start Small
- Week 1: Implement smart routing (30% savings)
- Week 2: Add prompt caching (additional 50% on cached)
- Week 3: Build knowledge base (additional 20% savings)
- Week 4: Enable batch API for scheduled tasks

### 2. Monitor Continuously
- Track costs daily
- Identify expensive queries
- Optimize routing rules
- Expand local knowledge base

### 3. Iterative Improvement
- Analyze which questions go to Claude
- Can they be answered locally?
- Download and index relevant docs
- Improve DeepSeek prompts for better accuracy

### 4. Quality over Cost
- Don't sacrifice accuracy to save money
- Use Claude for important/complex tasks
- Use DeepSeek for simple/routine tasks
- Verify DeepSeek responses periodically

---

## 🚀 Quick Start Checklist

- [ ] Install DeepSeek: `ollama pull deepseek-r1:7b`
- [ ] Get Claude API key from console.anthropic.com
- [ ] Create smart routing workflow in n8n
- [ ] Enable prompt caching on system prompts
- [ ] Start Qdrant: `docker compose up -d qdrant`
- [ ] Begin building local knowledge base
- [ ] Set up cost tracking in PostgreSQL
- [ ] Monitor savings weekly

---

## 📚 Additional Resources

- **Anthropic Prompt Caching:** https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching
- **Batch API Documentation:** https://docs.anthropic.com/en/api/batch-api
- **Token Counting:** https://docs.anthropic.com/en/docs/resources/model-deprecations
- **Pricing Calculator:** https://console.anthropic.com/settings/billing

---

**Your optimized setup can save $2,100-2,400/year while maintaining quality! 🚀**
