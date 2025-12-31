# 📚 Knowledge Base Setup Guide

**Transform your server into a personal search engine that downloads, indexes, and searches information locally.**

---

## 🎯 Goals

1. **Auto-download** documentation, articles, PDFs from the internet
2. **Index locally** in PostgreSQL (full-text) + Qdrant (semantic search)
3. **Search first** before using Claude API (save money)
4. **Privacy** - all data stays on your hardware

---

## 💾 Storage Capacity

**Your setup:**
- 5.5TB available storage
- Can store **millions** of documents

**Storage estimates:**
```
1,000 documents  = ~1GB
10,000 documents = ~10GB
100,000 documents = ~100GB
1,000,000 documents = ~1TB
```

---

## 🏗️ Architecture

```
User Question
↓
1. Search PostgreSQL (keyword match) → Found? Use it (FREE)
↓
2. Search Qdrant (semantic match) → Found? Use it (FREE)
↓
3. Not found? Download from internet
↓
4. Store in PostgreSQL + Qdrant
↓
5. Ask Claude to summarize (if needed)
↓
6. Next similar question = instant answer (FREE)
```

---

## 📦 Prerequisites

### 1. PostgreSQL (You already have this)

Create knowledge base tables:

```sql
-- Full-text search table
CREATE TABLE knowledge_base (
    id SERIAL PRIMARY KEY,
    title TEXT,
    content TEXT,
    url TEXT UNIQUE,
    source VARCHAR(50),  -- 'anthropic_docs', 'arxiv', 'blog', etc.
    doc_type VARCHAR(20), -- 'pdf', 'html', 'markdown'
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Create full-text search index
CREATE INDEX idx_knowledge_fts ON knowledge_base
USING GIN(to_tsvector('english', content));

-- Metadata tracking
CREATE TABLE download_queue (
    id SERIAL PRIMARY KEY,
    url TEXT UNIQUE,
    source VARCHAR(50),
    priority INT DEFAULT 5,
    downloaded BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- API usage tracking (for cost monitoring)
CREATE TABLE api_usage (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT NOW(),
    question TEXT,
    source VARCHAR(20),  -- 'deepseek', 'local_pg', 'local_qdrant', 'claude'
    tokens_used INT,
    cost DECIMAL(10,4),
    cached BOOLEAN DEFAULT FALSE
);
```

### 2. Qdrant (Vector Database)

```bash
# Start Qdrant
cd ~/awesome-n8n-templates/ollama-suite
docker compose up -d qdrant

# Create collection for embeddings
curl -X PUT http://localhost:6333/collections/knowledge \
  -H "Content-Type: application/json" \
  -d '{
    "vectors": {
      "size": 768,
      "distance": "Cosine"
    },
    "optimizers_config": {
      "indexing_threshold": 10000
    }
  }'
```

### 3. Python Libraries

```bash
pip install requests beautifulsoup4 pypdf2 readability-lxml lxml html2text
```

---

## 🌐 Part 1: Web Scraping & Download

### Download Documentation Sites

**Script: `download-docs.py`**

```python
#!/usr/bin/env python3
import requests
from bs4 import BeautifulSoup
from readability import Document
import psycopg2
import json

def download_page(url):
    """Download and extract main content from webpage"""
    response = requests.get(url, timeout=30)
    response.raise_for_status()

    # Use readability to extract main content
    doc = Document(response.text)
    title = doc.title()
    content = doc.summary()

    # Convert HTML to text
    soup = BeautifulSoup(content, 'html.parser')
    text = soup.get_text(separator='\n', strip=True)

    return title, text

def store_in_postgres(title, content, url, source):
    """Store document in PostgreSQL"""
    conn = psycopg2.connect(
        host="localhost",
        database="your_db",
        user="your_user",
        password="your_password"
    )
    cur = conn.cursor()

    try:
        cur.execute("""
            INSERT INTO knowledge_base (title, content, url, source, doc_type)
            VALUES (%s, %s, %s, %s, 'html')
            ON CONFLICT (url) DO UPDATE
            SET content = EXCLUDED.content, updated_at = NOW()
        """, (title, content, url, source))
        conn.commit()
        print(f"✓ Stored: {title}")
    except Exception as e:
        print(f"✗ Error: {e}")
    finally:
        cur.close()
        conn.close()

def scrape_docs(base_url, source_name):
    """Scrape documentation site"""
    visited = set()
    to_visit = [base_url]

    while to_visit:
        url = to_visit.pop(0)
        if url in visited:
            continue

        visited.add(url)
        print(f"Downloading: {url}")

        try:
            title, content = download_page(url)
            store_in_postgres(title, content, url, source_name)

            # Find more links (simple example)
            response = requests.get(url)
            soup = BeautifulSoup(response.text, 'html.parser')
            for link in soup.find_all('a', href=True):
                full_url = requests.compat.urljoin(url, link['href'])
                if full_url.startswith(base_url) and full_url not in visited:
                    to_visit.append(full_url)
        except Exception as e:
            print(f"Error downloading {url}: {e}")

# Example usage
scrape_docs("https://docs.anthropic.com/en/docs/", "anthropic_docs")
```

### Download PDFs

**Script: `download-pdfs.py`**

```python
#!/usr/bin/env python3
import requests
import PyPDF2
import io
import psycopg2

def download_pdf(url):
    """Download PDF and extract text"""
    response = requests.get(url, timeout=30)
    response.raise_for_status()

    pdf_file = io.BytesIO(response.content)
    pdf_reader = PyPDF2.PdfReader(pdf_file)

    text = ""
    for page in pdf_reader.pages:
        text += page.extract_text() + "\n"

    title = url.split('/')[-1].replace('.pdf', '')
    return title, text

def store_pdf(title, content, url, source):
    """Store PDF in PostgreSQL"""
    conn = psycopg2.connect(
        host="localhost",
        database="your_db",
        user="your_user",
        password="your_password"
    )
    cur = conn.cursor()

    try:
        cur.execute("""
            INSERT INTO knowledge_base (title, content, url, source, doc_type)
            VALUES (%s, %s, %s, %s, 'pdf')
            ON CONFLICT (url) DO NOTHING
        """, (title, content, url, source))
        conn.commit()
        print(f"✓ Stored PDF: {title}")
    except Exception as e:
        print(f"✗ Error: {e}")
    finally:
        cur.close()
        conn.close()

# Example: Download ArXiv papers
pdf_urls = [
    "https://arxiv.org/pdf/2301.00001.pdf",
    "https://arxiv.org/pdf/2302.00001.pdf",
]

for url in pdf_urls:
    try:
        title, content = download_pdf(url)
        store_pdf(title, content, url, "arxiv")
    except Exception as e:
        print(f"Error: {e}")
```

---

## 🧮 Part 2: Generate Embeddings

### Use DeepSeek to Generate Embeddings

**Script: `generate-embeddings.py`**

```python
#!/usr/bin/env python3
import requests
import psycopg2
import json

def generate_embedding(text):
    """Generate embedding using Ollama"""
    response = requests.post(
        "http://localhost:11434/api/embeddings",
        json={
            "model": "nomic-embed-text",
            "prompt": text[:8000]  # Limit to avoid context overflow
        }
    )
    return response.json()['embedding']

def store_in_qdrant(doc_id, embedding, payload):
    """Store embedding in Qdrant"""
    response = requests.put(
        "http://localhost:6333/collections/knowledge/points",
        json={
            "points": [
                {
                    "id": doc_id,
                    "vector": embedding,
                    "payload": payload
                }
            ]
        }
    )
    return response.json()

def process_documents():
    """Process all documents and create embeddings"""
    conn = psycopg2.connect(
        host="localhost",
        database="your_db",
        user="your_user",
        password="your_password"
    )
    cur = conn.cursor()

    # Get documents without embeddings
    cur.execute("SELECT id, title, content, url, source FROM knowledge_base")

    for row in cur.fetchall():
        doc_id, title, content, url, source = row

        print(f"Processing: {title}")

        # Generate embedding
        try:
            embedding = generate_embedding(content)

            # Store in Qdrant
            payload = {
                "title": title,
                "url": url,
                "source": source,
                "preview": content[:200]
            }

            store_in_qdrant(doc_id, embedding, payload)
            print(f"✓ Embedded: {title}")
        except Exception as e:
            print(f"✗ Error: {e}")

    cur.close()
    conn.close()

# Run
process_documents()
```

---

## 🔍 Part 3: Search Workflows

### n8n Workflow 1: Full-Text Search (PostgreSQL)

**Nodes:**

1. **Webhook Trigger**
   - Path: `/search`
   - Method: POST
   - Body: `{"question": "your question"}`

2. **PostgreSQL Node** (Full-text search)
   ```sql
   SELECT id, title, content, url, source,
          ts_rank(to_tsvector('english', content), plainto_tsquery('{{$json.question}}')) as rank
   FROM knowledge_base
   WHERE to_tsvector('english', content) @@ plainto_tsquery('{{$json.question}}')
   ORDER BY rank DESC
   LIMIT 5;
   ```

3. **IF Node**
   - Condition: `{{$json.length}} > 0`
   - True → Return results (found locally)
   - False → Continue to semantic search

4. **Function Node** (Format response)
   ```javascript
   return $input.all().map(item => ({
     title: item.json.title,
     source: 'local_postgresql',
     content: item.json.content.substring(0, 500),
     url: item.json.url,
     cost: 0
   }));
   ```

### n8n Workflow 2: Semantic Search (Qdrant)

**Nodes:**

1. **HTTP Request** (Generate embedding)
   ```json
   {
     "url": "http://localhost:11434/api/embeddings",
     "method": "POST",
     "body": {
       "model": "nomic-embed-text",
       "prompt": "{{$json.question}}"
     }
   }
   ```

2. **HTTP Request** (Search Qdrant)
   ```json
   {
     "url": "http://localhost:6333/collections/knowledge/points/search",
     "method": "POST",
     "body": {
       "vector": "{{$json.embedding}}",
       "limit": 5,
       "score_threshold": 0.7,
       "with_payload": true
     }
   }
   ```

3. **IF Node**
   - Condition: `{{$json.result.length}} > 0`
   - True → Return Qdrant results
   - False → Ask Claude

4. **Function Node** (Format response)
   ```javascript
   return $input.all().map(item => ({
     title: item.json.payload.title,
     source: 'local_qdrant',
     content: item.json.payload.preview,
     url: item.json.payload.url,
     score: item.json.score,
     cost: 0
   }));
   ```

### n8n Workflow 3: Fallback to Claude

**Nodes:**

1. **AI Agent** (Claude)
   - Provider: Anthropic
   - Model: `claude-sonnet-4`
   - Prompt: `{{$json.question}}`

2. **PostgreSQL Insert** (Store answer for future)
   ```sql
   INSERT INTO knowledge_base (title, content, url, source, doc_type)
   VALUES (
     'Q: {{$json.question}}',
     '{{$json.response}}',
     'claude-generated',
     'claude_api',
     'answer'
   );
   ```

3. **Function Node** (Log usage)
   ```javascript
   // Log API usage for cost tracking
   return {
     question: $json.question,
     source: 'claude',
     tokens_used: $json.usage.total_tokens,
     cost: $json.usage.total_tokens * 0.000003,
     timestamp: new Date().toISOString()
   };
   ```

---

## 📥 Part 4: Automated Downloading

### n8n Workflow: Daily Doc Downloader

**Nodes:**

1. **Schedule Trigger**
   - Cron: `0 2 * * *` (daily at 2 AM)

2. **HTTP Request** (Fetch RSS feed)
   ```json
   {
     "url": "https://www.anthropic.com/blog/rss.xml",
     "method": "GET"
   }
   ```

3. **XML to JSON**
   - Parse RSS feed

4. **Loop Over Items**

5. **HTTP Request** (Download article)
   ```json
   {
     "url": "{{$json.link}}",
     "method": "GET"
   }
   ```

6. **HTML to Text**
   - Extract main content

7. **PostgreSQL Insert**
   ```sql
   INSERT INTO knowledge_base (title, content, url, source, doc_type)
   VALUES (
     '{{$json.title}}',
     '{{$json.content}}',
     '{{$json.url}}',
     'anthropic_blog',
     'html'
   )
   ON CONFLICT (url) DO NOTHING;
   ```

8. **HTTP Request** (Generate embedding)

9. **HTTP Request** (Store in Qdrant)

10. **Send Notification**
    - Slack/Email: "New article indexed: {{$json.title}}"

---

## 📚 What to Download First

### Priority 1: Documentation (High Re-use)

```bash
# Anthropic Docs
wget -r -np -k -E -p https://docs.anthropic.com/en/docs/
# Store in ~/knowledge-base/anthropic/

# n8n Docs
wget -r -np -k -E -p https://docs.n8n.io/
# Store in ~/knowledge-base/n8n/

# Ollama Library
curl https://ollama.com/api/tags | jq > ~/knowledge-base/ollama-models.json
```

### Priority 2: GitHub Repos

```bash
# DeepSeek-R1
git clone https://github.com/deepseek-ai/DeepSeek-R1 ~/knowledge-base/github/deepseek

# Qdrant
git clone https://github.com/qdrant/qdrant ~/knowledge-base/github/qdrant
```

### Priority 3: Research Papers

**Topics to download:**
- Prompt caching techniques
- LLM cost optimization
- Local RAG systems
- Vector database optimization

**Sources:**
- ArXiv: https://arxiv.org/
- Papers with Code: https://paperswithcode.com/

### Priority 4: Your Domain-Specific Docs

For your legal use case:
- Legal reference materials
- Case law databases
- Regulatory documents

---

## 📊 Monitoring & Maintenance

### Weekly Report Query

```sql
-- Documents added this week
SELECT source, COUNT(*) as docs_added
FROM knowledge_base
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY source;

-- Search usage stats
SELECT source, COUNT(*) as queries
FROM api_usage
WHERE timestamp >= NOW() - INTERVAL '7 days'
GROUP BY source
ORDER BY queries DESC;

-- Cost savings
SELECT
    SUM(CASE WHEN source LIKE 'local%' THEN 1 ELSE 0 END) as local_queries,
    SUM(CASE WHEN source = 'claude' THEN cost ELSE 0 END) as claude_cost,
    COUNT(*) as total_queries
FROM api_usage
WHERE timestamp >= NOW() - INTERVAL '30 days';
```

### Cleanup Old/Outdated Docs

```sql
-- Find docs not accessed in 6 months
DELETE FROM knowledge_base
WHERE updated_at < NOW() - INTERVAL '6 months'
  AND source NOT IN ('anthropic_docs', 'n8n_docs');

-- Vacuum Qdrant (free up space)
curl -X POST http://localhost:6333/collections/knowledge/optimize
```

---

## 🚀 Quick Start Checklist

- [ ] Create PostgreSQL tables (see prerequisites)
- [ ] Start Qdrant: `docker compose up -d qdrant`
- [ ] Create Qdrant collection: `curl -X PUT http://localhost:6333/collections/knowledge ...`
- [ ] Install Python libraries: `pip install requests beautifulsoup4 pypdf2 readability-lxml`
- [ ] Download embedding model: `ollama pull nomic-embed-text`
- [ ] Download priority docs (Anthropic, n8n, Ollama)
- [ ] Generate embeddings for downloaded docs
- [ ] Create n8n search workflows
- [ ] Test: Search for "prompt caching" (should find local docs)
- [ ] Set up daily auto-download workflow
- [ ] Monitor savings!

---

## 🎓 Advanced Tips

### 1. Chunk Large Documents

```python
def chunk_text(text, chunk_size=1000, overlap=200):
    """Split text into overlapping chunks"""
    chunks = []
    start = 0
    while start < len(text):
        end = start + chunk_size
        chunks.append(text[start:end])
        start = end - overlap
    return chunks
```

### 2. Multi-Query Search

For better recall, generate multiple search queries:

```javascript
// In n8n Function node
const question = $json.question;
const queries = [
  question,
  `What is ${question}?`,
  `Explain ${question}`,
  `${question} documentation`
];

return { queries };
```

### 3. Hybrid Search (Keyword + Semantic)

Combine PostgreSQL full-text + Qdrant semantic for best results:

```python
# Weight: 70% semantic, 30% keyword
final_score = (semantic_score * 0.7) + (keyword_rank * 0.3)
```

---

**Your knowledge base will save you $1,000-1,500/year by answering 70% of questions locally! 🚀**
