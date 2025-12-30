# AI Empire n8n Workflows

Pre-built workflow templates for the AI Empire deployment.

## Available Workflows

### 1. Fabric Content Extraction Pipeline
**File:** `fabric-content-extraction.json`

**Purpose:** Extract wisdom and insights from long-form content using Fabric patterns.

**Flow:**
1. Receives content via webhook (POST /extract-content)
2. Executes Fabric `extract_wisdom` pattern via Fabric Bridge
3. Saves extracted data to PostgreSQL
4. Returns results

**Usage:**
```bash
curl -X POST http://localhost:5678/webhook/extract-content \
  -H "Content-Type: application/json" \
  -d '{"content": "Your long article text here..."}'
```

**Features:**
- Automatic model selection (DeepSeek if VRAM available)
- Cost tracking
- Historical data storage for fine-tuning

---

### 2. VRAM-Aware Intelligent Routing
**File:** `vram-aware-routing.json`

**Purpose:** Dynamically route requests to local DeepSeek (free) or Claude API (paid) based on GPU availability.

**Flow:**
1. Receives inference request via webhook
2. Checks current VRAM status
3. Routes to DeepSeek R1-8B (free) if VRAM available
4. Falls back to Claude API (paid) if GPU busy
5. Logs all requests with cost tracking
6. Returns results

**Usage:**
```bash
curl -X POST http://localhost:5678/webhook/smart-inference \
  -H "Content-Type: application/json" \
  -d '{
    "pattern": "summarize",
    "input": "Your text to summarize..."
  }'
```

**Cost Savings:**
- Automatically uses FREE local inference when possible
- Only uses paid Claude API when necessary
- Tracks cost per request for budget monitoring

---

## Installation

### Import to n8n

1. Open n8n at http://localhost:5678
2. Click "Workflows" → "Import"
3. Select one of the JSON files
4. Configure credentials:
   - PostgreSQL: Use `ai_empire` database
   - HTTP credentials: None needed (localhost)

### Configure Database

Both workflows require PostgreSQL tables:

```sql
-- For content extraction workflow
CREATE TABLE extracted_content (
    id SERIAL PRIMARY KEY,
    source_url TEXT,
    extracted_data JSONB,
    model_used VARCHAR(50),
    cost DECIMAL(10,4),
    created_at TIMESTAMP DEFAULT NOW()
);

-- For intelligent routing workflow
CREATE TABLE inference_logs (
    id SERIAL PRIMARY KEY,
    pattern VARCHAR(100),
    input_text TEXT,
    output_text TEXT,
    model_used VARCHAR(50),
    cost DECIMAL(10,4),
    response_time_ms INTEGER,
    vram_available BOOLEAN,
    created_at TIMESTAMP DEFAULT NOW()
);
```

### Test the Workflows

After importing:

1. Activate the workflow in n8n
2. Copy the webhook URL
3. Send a test request using curl (see examples above)
4. Check the execution log in n8n

---

## Integration with Fabric Bridge

All workflows use the Fabric n8n Bridge API running on port 8080.

**Endpoints used:**
- `POST /execute` - Execute Fabric patterns
- `GET /vram` - Check VRAM availability
- `GET /patterns` - List available patterns

**Ensure the bridge is running:**
```bash
sudo systemctl status fabric-bridge
```

---

## Advanced Patterns

### Batch Processing

Create a workflow that:
1. Reads files from a directory
2. Processes each with Fabric
3. Aggregates results
4. Saves to vector database for RAG

### Automated Documentation

On git push:
1. Get changed Python files
2. Run `explain_code` pattern
3. Generate markdown docs
4. Commit back to repo

### Smart Caching

1. Check Redis for cached response
2. If miss, execute Fabric pattern
3. Cache result with TTL
4. Return cached or fresh result

---

## Cost Optimization Tips

1. **Use VRAM-aware routing** - Saves 80%+ on inference costs
2. **Cache responses** - Add Redis caching before Fabric execution
3. **Batch requests** - Process multiple items in single API call
4. **Monitor costs** - Query `inference_logs` table for spending analysis

```sql
-- Daily cost summary
SELECT
    DATE(created_at) as date,
    model_used,
    COUNT(*) as requests,
    SUM(cost) as total_cost
FROM inference_logs
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY DATE(created_at), model_used
ORDER BY date DESC;
```

---

## Troubleshooting

**Workflow not executing:**
- Check if webhook is activated
- Verify Fabric Bridge is running: `curl http://localhost:8080/health`
- Check n8n logs: `docker logs ai-empire-n8n`

**High costs:**
- Verify VRAM routing is working
- Check if DeepSeek model is loaded: `ollama ps`
- Review inference logs for model distribution

**PostgreSQL connection errors:**
- Verify database is running: `docker ps | grep postgres`
- Check credentials in n8n settings
- Test connection: `psql -h localhost -U postgres -d ai_empire`

---

## Creating Custom Workflows

### Template Structure

```json
{
  "name": "Your Workflow Name",
  "nodes": [
    {
      "name": "Webhook",
      "type": "n8n-nodes-base.webhook",
      "parameters": {
        "path": "your-endpoint",
        "httpMethod": "POST"
      }
    },
    {
      "name": "Execute Fabric",
      "type": "n8n-nodes-base.httpRequest",
      "parameters": {
        "url": "http://localhost:8080/execute",
        "method": "POST",
        "bodyParametersJson": {
          "pattern": "your_pattern",
          "input": "{{ $json.input }}"
        }
      }
    }
  ],
  "connections": {
    "Webhook": {
      "main": [[{"node": "Execute Fabric"}]]
    }
  }
}
```

### Available Fabric Patterns

- `extract_wisdom` - Extract insights from content
- `summarize` - Smart summarization
- `create_quiz` - Generate questions
- `explain_code` - Code documentation
- `improve_writing` - Writing enhancement
- `create_alpaca_dataset` - Format for fine-tuning
- ...300+ more patterns available

**List all patterns:**
```bash
fabric --list
```

---

## Contributing

Add your custom workflows to this directory and submit a PR!

**Requirements:**
- Must use Fabric Bridge API
- Must include cost tracking
- Must handle errors gracefully
- Must include usage examples

---

## Support

- Full documentation: [README.md](../README.md)
- Fabric documentation: https://github.com/danielmiessler/fabric
- n8n documentation: https://docs.n8n.io

---

**Happy Automating! 🚀**
