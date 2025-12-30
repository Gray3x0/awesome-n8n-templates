#!/bin/bash

################################################################################
# Integration Tools Installation Module
# Installs: Continue.dev, Fabric, AIChat, n8n, Flowise, Dify
################################################################################

source "$(dirname "$0")/../install-ollama-suite.sh" 2>/dev/null || true

install_integrations() {
    print_header "Installing Integration Tools"

    install_fabric
    install_aichat
    install_n8n
    install_flowise
    install_dify
    install_continue_dev_config
    install_litellm

    print_status "All integration tools installed!"
}

install_fabric() {
    print_status "Installing Fabric (AI prompt patterns CLI)..."

    # Install Go if not present
    if ! command -v go &> /dev/null; then
        print_warning "Go not found. Installing..."
        wget https://go.dev/dl/go1.22.0.linux-amd64.tar.gz
        sudo tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
        export PATH=$PATH:/usr/local/go/bin
        rm go1.22.0.linux-amd64.tar.gz
    fi

    # Install Fabric
    go install github.com/danielmiessler/fabric@latest

    # Add to PATH
    echo 'export PATH=$PATH:$HOME/go/bin' >> ~/.bashrc
    export PATH=$PATH:$HOME/go/bin

    # Setup Fabric
    fabric --setup

    # Configure for Ollama
    mkdir -p ~/.config/fabric
    cat > ~/.config/fabric/config.yaml << 'EOF'
DefaultModel: ollama:deepseek-r1:7b
DefaultVendor: Ollama

Vendors:
  Ollama:
    DefaultModel: deepseek-r1:7b
    BaseURL: http://localhost:11434
EOF

    # Create example patterns directory
    fabric --updatepatterns

    print_status "Fabric installed!"
    print_info "Try: echo 'Long text...' | fabric --pattern summarize"
    print_info "Or: fabric --list-patterns"
}

install_aichat() {
    print_status "Installing AIChat (All-in-one CLI)..."

    # Download latest release
    AICHAT_VERSION="0.20.0"
    wget "https://github.com/sigoden/aichat/releases/download/v${AICHAT_VERSION}/aichat-v${AICHAT_VERSION}-x86_64-unknown-linux-musl.tar.gz"
    tar -xzf "aichat-v${AICHAT_VERSION}-x86_64-unknown-linux-musl.tar.gz"
    sudo mv aichat /usr/local/bin/
    rm "aichat-v${AICHAT_VERSION}-x86_64-unknown-linux-musl.tar.gz"

    # Configure for Ollama
    mkdir -p ~/.config/aichat
    cat > ~/.config/aichat/config.yaml << 'EOF'
model: ollama:deepseek-r1:7b
temperature: 0.7
save: true
highlight: true

clients:
  - type: ollama
    api_base: http://localhost:11434
    models:
      - name: deepseek-r1:7b
        max_input_tokens: 4096
      - name: qwen2.5:7b
        max_input_tokens: 4096
      - name: llama3.2:3b
        max_input_tokens: 8192
EOF

    print_status "AIChat installed!"
    print_info "Usage:"
    print_info "  aichat 'What is machine learning?'"
    print_info "  aichat --role shell 'list all docker containers'"
    print_info "  aichat --session mysession 'Hello'"
}

install_n8n() {
    print_status "Installing n8n (Workflow automation)..."

    docker run -d \
        --name n8n \
        -p 5678:5678 \
        --add-host=host.docker.internal:host-gateway \
        -v "$DATA_DIR/n8n:/home/node/.n8n" \
        -e N8N_HOST=localhost \
        -e N8N_PORT=5678 \
        -e N8N_PROTOCOL=http \
        -e WEBHOOK_URL=http://localhost:5678/ \
        --restart always \
        n8nio/n8n

    # Create example Ollama node workflow
    mkdir -p "$PROJECTS_DIR/n8n-workflows"
    cat > "$PROJECTS_DIR/n8n-workflows/ollama-example.json" << 'EOF'
{
  "name": "Ollama Chat Workflow",
  "nodes": [
    {
      "parameters": {},
      "name": "Webhook",
      "type": "n8n-nodes-base.webhook",
      "position": [250, 300]
    },
    {
      "parameters": {
        "url": "http://host.docker.internal:11434/api/chat",
        "method": "POST",
        "jsonParameters": true,
        "options": {},
        "bodyParametersJson": "={\n  \"model\": \"deepseek-r1:7b\",\n  \"messages\": [\n    {\n      \"role\": \"user\",\n      \"content\": \"{{ $json.query }}\"\n    }\n  ],\n  \"stream\": false\n}"
      },
      "name": "HTTP Request",
      "type": "n8n-nodes-base.httpRequest",
      "position": [450, 300]
    }
  ],
  "connections": {
    "Webhook": {
      "main": [[{"node": "HTTP Request", "type": "main", "index": 0}]]
    }
  }
}
EOF

    print_status "n8n installed! Access at: http://localhost:5678"
    print_info "Example workflow: $PROJECTS_DIR/n8n-workflows/ollama-example.json"
}

install_flowise() {
    print_status "Installing Flowise (Visual LLM builder)..."

    docker run -d \
        --name flowise \
        -p 3005:3000 \
        --add-host=host.docker.internal:host-gateway \
        -v "$DATA_DIR/flowise:/root/.flowise" \
        -e FLOWISE_USERNAME=admin \
        -e FLOWISE_PASSWORD=admin \
        -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
        --restart always \
        flowiseai/flowise

    print_status "Flowise installed! Access at: http://localhost:3005"
    print_info "Login with: admin / admin (change after first login)"
}

install_dify() {
    print_status "Installing Dify (LLM app builder)..."

    cd "$PROJECTS_DIR"

    if [ -d "dify" ]; then
        cd dify
        git pull
    else
        git clone https://github.com/langgenius/dify.git
        cd dify/docker
    fi

    # Create custom .env for Ollama
    cat > .env << 'EOF'
# Dify Configuration
SECRET_KEY=your-secret-key-change-this
CONSOLE_API_URL=http://localhost
CONSOLE_WEB_URL=http://localhost:3006
SERVICE_API_URL=http://localhost
APP_WEB_URL=http://localhost:3006

# Database
DB_USERNAME=postgres
DB_PASSWORD=difyai123456
DB_HOST=db
DB_PORT=5432
DB_DATABASE=dify

# Redis
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_DB=0
REDIS_PASSWORD=

# Celery
CELERY_BROKER_URL=redis://:@redis:6379/1

# Storage
STORAGE_TYPE=local
STORAGE_LOCAL_PATH=storage

# Vector Database
VECTOR_STORE=qdrant
QDRANT_URL=http://host.docker.internal:6333
QDRANT_API_KEY=

# Ollama
OLLAMA_API_BASE_URL=http://host.docker.internal:11434
EOF

    # Update docker-compose to use custom port
    sed -i 's/80:80/3006:80/g' docker-compose.yaml

    docker compose up -d

    print_status "Dify installed! Access at: http://localhost:3006"
    print_info "Configure Ollama as LLM provider in settings"
}

install_continue_dev_config() {
    print_status "Creating Continue.dev configuration for VSCode..."

    mkdir -p ~/.continue
    cat > ~/.continue/config.json << 'EOF'
{
  "models": [
    {
      "title": "DeepSeek R1 7B",
      "provider": "ollama",
      "model": "deepseek-r1:7b",
      "apiBase": "http://localhost:11434"
    },
    {
      "title": "Qwen 2.5 7B",
      "provider": "ollama",
      "model": "qwen2.5:7b",
      "apiBase": "http://localhost:11434"
    },
    {
      "title": "Llama 3.2 3B (Fast)",
      "provider": "ollama",
      "model": "llama3.2:3b",
      "apiBase": "http://localhost:11434"
    }
  ],
  "tabAutocompleteModel": {
    "title": "Starcoder2 3B",
    "provider": "ollama",
    "model": "starcoder2:3b",
    "apiBase": "http://localhost:11434"
  },
  "embeddingsProvider": {
    "provider": "ollama",
    "model": "nomic-embed-text",
    "apiBase": "http://localhost:11434"
  },
  "slashCommands": [
    {
      "name": "edit",
      "description": "Edit highlighted code"
    },
    {
      "name": "comment",
      "description": "Write comments for code"
    },
    {
      "name": "share",
      "description": "Export chat to markdown"
    },
    {
      "name": "cmd",
      "description": "Generate shell command"
    }
  ],
  "customCommands": [
    {
      "name": "test",
      "prompt": "Write unit tests for the selected code",
      "description": "Generate unit tests"
    }
  ],
  "contextProviders": [
    {
      "name": "code",
      "params": {}
    },
    {
      "name": "docs",
      "params": {}
    },
    {
      "name": "diff",
      "params": {}
    },
    {
      "name": "terminal",
      "params": {}
    },
    {
      "name": "problems",
      "params": {}
    },
    {
      "name": "folder",
      "params": {}
    },
    {
      "name": "codebase",
      "params": {}
    }
  ],
  "allowAnonymousTelemetry": false,
  "docs": []
}
EOF

    print_status "Continue.dev configuration created!"
    print_info "Install extension in VSCode: https://marketplace.visualstudio.com/items?itemName=Continue.continue"
}

install_litellm() {
    print_status "Installing LiteLLM (Universal API gateway)..."

    pip install 'litellm[proxy]' --break-system-packages 2>/dev/null || \
    pip install 'litellm[proxy]'

    # Create configuration
    cat > "$PROJECTS_DIR/litellm_config.yaml" << 'EOF'
model_list:
  - model_name: deepseek-r1
    litellm_params:
      model: ollama/deepseek-r1:7b
      api_base: http://localhost:11434

  - model_name: qwen2.5
    litellm_params:
      model: ollama/qwen2.5:7b
      api_base: http://localhost:11434

  - model_name: llama3.2
    litellm_params:
      model: ollama/llama3.2:3b
      api_base: http://localhost:11434

general_settings:
  master_key: sk-1234  # Change this!
  database_url: sqlite:///litellm.db

litellm_settings:
  drop_params: true
  set_verbose: false
  request_timeout: 600
  num_retries: 3

router_settings:
  routing_strategy: usage-based-routing
  model_group_alias:
    gpt-4: deepseek-r1
    gpt-3.5-turbo: llama3.2
EOF

    # Create startup script
    cat > "$PROJECTS_DIR/start-litellm.sh" << 'EOF'
#!/bin/bash
litellm --config litellm_config.yaml --port 4000 --detailed_debug
EOF

    chmod +x "$PROJECTS_DIR/start-litellm.sh"

    print_status "LiteLLM installed!"
    print_info "Start with: cd $PROJECTS_DIR && ./start-litellm.sh"
    print_info "Access OpenAI-compatible API at: http://localhost:4000"
}

export -f install_integrations
