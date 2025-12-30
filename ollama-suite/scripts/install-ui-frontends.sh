#!/bin/bash

################################################################################
# UI Frontends Installation Module
# Installs: Open WebUI, LibreChat, AnythingLLM, Chatbot UI
################################################################################

source "$(dirname "$0")/../install-ollama-suite.sh" 2>/dev/null || true

install_ui_frontends() {
    print_header "Installing UI Frontends"

    # Install Open WebUI
    install_open_webui

    # Install LibreChat
    install_librechat

    # Install AnythingLLM
    install_anythingllm

    # Install Chatbot UI
    install_chatbot_ui

    print_status "All UI frontends installed!"
}

install_open_webui() {
    print_status "Installing Open WebUI..."

    cd "$PROJECTS_DIR"

    # Check if already cloned
    if [ -d "open-webui" ]; then
        print_warning "Open WebUI directory exists, pulling latest..."
        cd open-webui
        git pull
    else
        git clone https://github.com/open-webui/open-webui.git
        cd open-webui
    fi

    # Docker installation (recommended)
    docker run -d \
        --name open-webui \
        -p 3000:8080 \
        --gpus all \
        --add-host=host.docker.internal:host-gateway \
        -v open-webui:/app/backend/data \
        -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
        -e WEBUI_AUTH=false \
        --restart always \
        ghcr.io/open-webui/open-webui:main

    print_status "Open WebUI installed! Access at: http://localhost:3000"

    # Create systemd service for monitoring
    create_open_webui_service
}

install_librechat() {
    print_status "Installing LibreChat..."

    cd "$PROJECTS_DIR"

    if [ -d "LibreChat" ]; then
        print_warning "LibreChat directory exists, pulling latest..."
        cd LibreChat
        git pull
    else
        git clone https://github.com/danny-avila/LibreChat.git
        cd LibreChat
    fi

    # Create configuration
    cat > .env << EOF
# Ollama Configuration
OLLAMA_BASE_URL=http://host.docker.internal:11434

# General Settings
HOST=0.0.0.0
PORT=3001

# Endpoints
ENDPOINTS=ollama

# Session
SESSION_EXPIRY=1000 * 60 * 15
REFRESH_TOKEN_EXPIRY=(1000 * 60 * 60 * 24) * 7

# Security
JWT_SECRET=$(openssl rand -base64 32)
JWT_REFRESH_SECRET=$(openssl rand -base64 32)

# Disable registration (optional)
ALLOW_REGISTRATION=true
EOF

    # Start with Docker Compose
    docker compose up -d

    print_status "LibreChat installed! Access at: http://localhost:3001"
}

install_anythingllm() {
    print_status "Installing AnythingLLM..."

    docker run -d \
        --name anythingllm \
        -p 3002:3001 \
        --add-host=host.docker.internal:host-gateway \
        -v "$DATA_DIR/anythingllm:/app/server/storage" \
        -e STORAGE_DIR=/app/server/storage \
        -e OLLAMA_BASE_PATH=http://host.docker.internal:11434 \
        --restart always \
        mintplexlabs/anythingllm

    print_status "AnythingLLM installed! Access at: http://localhost:3002"
}

install_chatbot_ui() {
    print_status "Installing Chatbot UI..."

    cd "$PROJECTS_DIR"

    if [ -d "chatbot-ui" ]; then
        cd chatbot-ui
        git pull
    else
        git clone https://github.com/mckaywrigley/chatbot-ui.git
        cd chatbot-ui
    fi

    # Create environment file
    cat > .env.local << EOF
# Ollama Configuration
NEXT_PUBLIC_OLLAMA_URL=http://localhost:11434

# Optional: Default model
DEFAULT_MODEL=llama3.2:3b
EOF

    # Build and run
    npm install

    # Create Docker container
    docker build -t chatbot-ui .
    docker run -d \
        --name chatbot-ui \
        -p 3010:3000 \
        --add-host=host.docker.internal:host-gateway \
        -e NEXT_PUBLIC_OLLAMA_URL=http://host.docker.internal:11434 \
        --restart always \
        chatbot-ui

    print_status "Chatbot UI installed! Access at: http://localhost:3010"
}

create_open_webui_service() {
    # Create a systemd service to ensure Open WebUI starts with Docker
    sudo tee /etc/systemd/system/open-webui.service > /dev/null << 'EOF'
[Unit]
Description=Open WebUI for Ollama
After=docker.service ollama.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/docker start open-webui
ExecStop=/usr/bin/docker stop open-webui

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable open-webui.service
}

# Export function for sourcing
export -f install_ui_frontends
