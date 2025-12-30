#!/bin/bash

################################################################################
# RAG Systems Installation Module
# Installs: PrivateGPT, Qdrant, LlamaIndex, Langflow, ChromaDB
################################################################################

source "$(dirname "$0")/../install-ollama-suite.sh" 2>/dev/null || true

install_rag_systems() {
    print_header "Installing RAG Systems"

    # Install Qdrant vector database
    install_qdrant

    # Install PrivateGPT
    install_privategpt

    # Install LlamaIndex
    install_llamaindex

    # Install Langflow
    install_langflow

    # Install ChromaDB (alternative)
    install_chromadb

    print_status "All RAG systems installed!"
}

install_qdrant() {
    print_status "Installing Qdrant vector database..."

    # Run Qdrant in Docker
    docker run -d \
        --name qdrant \
        -p 6333:6333 \
        -p 6334:6334 \
        -v "$DATA_DIR/qdrant_storage:/qdrant/storage:z" \
        --restart always \
        qdrant/qdrant

    # Install Python client
    pip install qdrant-client --break-system-packages 2>/dev/null || pip install qdrant-client

    # Create example configuration
    cat > "$PROJECTS_DIR/qdrant_example.py" << 'EOF'
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams

# Connect to Qdrant
client = QdrantClient(host="localhost", port=6333)

# Create collection
client.create_collection(
    collection_name="documents",
    vectors_config=VectorParams(size=768, distance=Distance.COSINE),
)

print("Qdrant is ready! Collection 'documents' created.")
EOF

    print_status "Qdrant installed! Dashboard: http://localhost:6333/dashboard"
}

install_privategpt() {
    print_status "Installing PrivateGPT..."

    cd "$PROJECTS_DIR"

    if [ -d "private-gpt" ]; then
        cd private-gpt
        git pull
    else
        git clone https://github.com/zylon-ai/private-gpt.git
        cd private-gpt
    fi

    # Create virtual environment
    python3 -m venv venv
    source venv/bin/activate

    # Install with Ollama support
    pip install poetry
    poetry install --extras "ui llms-ollama embeddings-ollama vector-stores-qdrant"

    # Create configuration
    cat > settings-ollama.yaml << EOF
llm:
  mode: ollama

ollama:
  llm_model: deepseek-r1:7b
  embedding_model: nomic-embed-text
  api_base: http://localhost:11434
  keep_alive: 5m
  request_timeout: 120.0

embedding:
  mode: ollama
  embed_dim: 768

vectorstore:
  database: qdrant

qdrant:
  path: $DATA_DIR/qdrant_storage

local:
  prompt_style: "llama2"

ui:
  enabled: true
  path: /
  default_chat_system_prompt: >
    You are a helpful AI assistant with access to documents.
    Use the context provided to answer questions accurately.
  default_query_system_prompt: >
    Answer questions based on the context provided.

server:
  env_name: local
  port: 8001
EOF

    # Create startup script
    cat > start-privategpt.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
PGPT_PROFILES=ollama poetry run python -m private_gpt
EOF

    chmod +x start-privategpt.sh

    deactivate

    print_status "PrivateGPT installed!"
    print_info "Start with: cd $PROJECTS_DIR/private-gpt && ./start-privategpt.sh"
    print_info "Access at: http://localhost:8001"
}

install_llamaindex() {
    print_status "Installing LlamaIndex..."

    # Install LlamaIndex with Ollama support
    pip install llama-index \
        llama-index-llms-ollama \
        llama-index-embeddings-ollama \
        llama-index-vector-stores-qdrant \
        --break-system-packages 2>/dev/null || \
    pip install llama-index \
        llama-index-llms-ollama \
        llama-index-embeddings-ollama \
        llama-index-vector-stores-qdrant

    # Create example RAG script
    cat > "$PROJECTS_DIR/llamaindex_rag_example.py" << 'EOF'
#!/usr/bin/env python3
"""
LlamaIndex RAG Example with Ollama
"""

from llama_index.core import VectorStoreIndex, SimpleDirectoryReader, Settings
from llama_index.llms.ollama import Ollama
from llama_index.embeddings.ollama import OllamaEmbedding
from llama_index.vector_stores.qdrant import QdrantVectorStore
from qdrant_client import QdrantClient
import sys

# Configure Ollama
Settings.llm = Ollama(model="deepseek-r1:7b", request_timeout=120.0)
Settings.embed_model = OllamaEmbedding(model_name="nomic-embed-text")

# Configure Qdrant
client = QdrantClient(host="localhost", port=6333)
vector_store = QdrantVectorStore(client=client, collection_name="documents")

def create_index(data_dir):
    """Create index from documents"""
    print(f"Loading documents from {data_dir}...")
    documents = SimpleDirectoryReader(data_dir).load_data()

    print("Creating index...")
    index = VectorStoreIndex.from_documents(
        documents,
        vector_store=vector_store
    )

    print("Index created successfully!")
    return index

def query_index(index, question):
    """Query the index"""
    query_engine = index.as_query_engine()
    response = query_engine.query(question)
    return response

if __name__ == "__main__":
    # Example usage
    data_directory = sys.argv[1] if len(sys.argv) > 1 else "./data"

    # Create or load index
    index = create_index(data_directory)

    # Interactive query loop
    print("\nRAG System Ready! Ask questions (type 'quit' to exit):")
    while True:
        question = input("\nQuestion: ").strip()
        if question.lower() in ['quit', 'exit', 'q']:
            break

        response = query_index(index, question)
        print(f"\nAnswer: {response}")
EOF

    chmod +x "$PROJECTS_DIR/llamaindex_rag_example.py"

    print_status "LlamaIndex installed!"
    print_info "Example script: $PROJECTS_DIR/llamaindex_rag_example.py"
}

install_langflow() {
    print_status "Installing Langflow..."

    # Create virtual environment
    python3 -m venv "$PROJECTS_DIR/langflow_env"
    source "$PROJECTS_DIR/langflow_env/bin/activate"

    pip install langflow

    # Create startup script
    cat > "$PROJECTS_DIR/start-langflow.sh" << 'EOF'
#!/bin/bash
source "$(dirname "$0")/langflow_env/bin/activate"
langflow run --host 0.0.0.0 --port 7860
EOF

    chmod +x "$PROJECTS_DIR/start-langflow.sh"

    deactivate

    print_status "Langflow installed!"
    print_info "Start with: $PROJECTS_DIR/start-langflow.sh"
    print_info "Access at: http://localhost:7860"
}

install_chromadb() {
    print_status "Installing ChromaDB (alternative vector DB)..."

    pip install chromadb --break-system-packages 2>/dev/null || pip install chromadb

    # Create example
    cat > "$PROJECTS_DIR/chromadb_example.py" << 'EOF'
import chromadb

# Create client
chroma_client = chromadb.Client()

# Create collection
collection = chroma_client.create_collection(name="documents")

# Example: Add documents
collection.add(
    documents=["This is document 1", "This is document 2"],
    metadatas=[{"source": "doc1"}, {"source": "doc2"}],
    ids=["id1", "id2"]
)

# Query
results = collection.query(
    query_texts=["search query"],
    n_results=2
)

print("ChromaDB ready!")
print(results)
EOF

    print_status "ChromaDB installed!"
}

export -f install_rag_systems
