#!/bin/bash

################################################################################
# Monitoring & Observability Installation Module
# Installs: Langfuse, Prometheus, Grafana, Ollama Monitor
################################################################################

source "$(dirname "$0")/../install-ollama-suite.sh" 2>/dev/null || true

install_monitoring() {
    print_header "Installing Monitoring & Observability Tools"

    install_langfuse
    install_prometheus_grafana
    install_ollama_exporter
    create_grafana_dashboards

    print_status "All monitoring tools installed!"
}

install_langfuse() {
    print_status "Installing Langfuse (LLM Observability)..."

    cd "$PROJECTS_DIR"

    # Create Langfuse directory
    mkdir -p langfuse
    cd langfuse

    # Create docker-compose for Langfuse
    cat > docker-compose.yml << 'EOF'
version: "3.8"

services:
  langfuse-server:
    image: langfuse/langfuse:latest
    depends_on:
      - langfuse-db
    ports:
      - "3003:3000"
    environment:
      - DATABASE_URL=postgresql://langfuse:langfuse@langfuse-db:5432/langfuse
      - NEXTAUTH_SECRET=your-secret-key-change-this
      - NEXTAUTH_URL=http://localhost:3003
      - SALT=your-salt-change-this
      - TELEMETRY_ENABLED=false
    restart: always

  langfuse-db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_USER=langfuse
      - POSTGRES_PASSWORD=langfuse
      - POSTGRES_DB=langfuse
    volumes:
      - langfuse_db_data:/var/lib/postgresql/data
    restart: always

volumes:
  langfuse_db_data:
EOF

    # Start Langfuse
    docker compose up -d

    # Install Python SDK
    pip install langfuse --break-system-packages 2>/dev/null || pip install langfuse

    # Create example integration
    cat > ../langfuse_example.py << 'EOF'
#!/usr/bin/env python3
"""
Langfuse Integration Example with Ollama
"""

from langfuse import Langfuse
from langfuse.decorators import observe, langfuse_context
import ollama

# Initialize Langfuse
langfuse = Langfuse(
    public_key="pk-lf-...",  # Get from Langfuse UI
    secret_key="sk-lf-...",  # Get from Langfuse UI
    host="http://localhost:3003"
)

@observe()
def query_ollama(prompt: str, model: str = "deepseek-r1:7b"):
    """Traced Ollama query"""

    response = ollama.chat(
        model=model,
        messages=[{"role": "user", "content": prompt}]
    )

    # Log to Langfuse
    langfuse_context.update_current_trace(
        name="ollama_query",
        metadata={"model": model},
        tags=["ollama", "local"]
    )

    return response["message"]["content"]

@observe()
def multi_step_task(task: str):
    """Example multi-step traced task"""

    # Step 1: Planning
    plan = query_ollama(f"Create a plan for: {task}")

    # Step 2: Execution
    result = query_ollama(f"Execute this plan: {plan}")

    return result

if __name__ == "__main__":
    result = multi_step_task("Research local LLM deployment best practices")
    print(result)

    # Flush traces
    langfuse.flush()
EOF

    chmod +x ../langfuse_example.py

    print_status "Langfuse installed! Access at: http://localhost:3003"
    print_info "Default credentials will be created on first access"
}

install_prometheus_grafana() {
    print_status "Installing Prometheus + Grafana monitoring stack..."

    cd "$PROJECTS_DIR"
    mkdir -p monitoring
    cd monitoring

    # Create Prometheus config
    cat > prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'ollama'
    static_configs:
      - targets: ['ollama-exporter:8000']

  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'nvidia'
    static_configs:
      - targets: ['nvidia-exporter:9835']
EOF

    # Create Grafana datasource config
    mkdir -p grafana/provisioning/datasources
    cat > grafana/provisioning/datasources/datasources.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

    # Create Docker Compose for monitoring stack
    cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.enable-lifecycle'
    restart: always

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3004:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SERVER_ROOT_URL=http://localhost:3004
    restart: always

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    restart: always

  nvidia-exporter:
    image: utkuozdemir/nvidia_gpu_exporter:latest
    container_name: nvidia-exporter
    ports:
      - "9835:9835"
    volumes:
      - /usr/lib/x86_64-linux-gnu/libnvidia-ml.so:/usr/lib/x86_64-linux-gnu/libnvidia-ml.so
      - /usr/lib/x86_64-linux-gnu/libnvidia-ml.so.1:/usr/lib/x86_64-linux-gnu/libnvidia-ml.so.1
      - /usr/bin/nvidia-smi:/usr/bin/nvidia-smi
    devices:
      - /dev/nvidiactl:/dev/nvidiactl
      - /dev/nvidia0:/dev/nvidia0
    restart: always

volumes:
  prometheus_data:
  grafana_data:
EOF

    docker compose up -d

    print_status "Prometheus + Grafana installed!"
    print_info "Prometheus: http://localhost:9090"
    print_info "Grafana: http://localhost:3004 (admin/admin)"
}

install_ollama_exporter() {
    print_status "Installing Ollama Prometheus Exporter..."

    cd "$PROJECTS_DIR"
    mkdir -p ollama-exporter
    cd ollama-exporter

    # Create Python exporter
    cat > exporter.py << 'EOF'
#!/usr/bin/env python3
"""
Ollama Prometheus Exporter
Exposes Ollama metrics for Prometheus
"""

from prometheus_client import start_http_server, Gauge, Counter, Histogram
import requests
import time
import os

# Metrics
ollama_requests_total = Counter('ollama_requests_total', 'Total Ollama requests')
ollama_tokens_generated = Counter('ollama_tokens_generated_total', 'Total tokens generated')
ollama_response_time = Histogram('ollama_response_time_seconds', 'Ollama response time')
ollama_models_loaded = Gauge('ollama_models_loaded', 'Number of models loaded')
ollama_vram_used = Gauge('ollama_vram_used_bytes', 'VRAM used by Ollama')

OLLAMA_HOST = os.getenv('OLLAMA_HOST', 'http://localhost:11434')

def collect_metrics():
    """Collect Ollama metrics"""
    try:
        # Get running models
        response = requests.get(f"{OLLAMA_HOST}/api/ps")
        if response.status_code == 200:
            data = response.json()
            models = data.get('models', [])
            ollama_models_loaded.set(len(models))

            # Calculate VRAM usage
            total_vram = sum(model.get('size_vram', 0) for model in models)
            ollama_vram_used.set(total_vram)

    except Exception as e:
        print(f"Error collecting metrics: {e}")

if __name__ == '__main__':
    # Start HTTP server
    start_http_server(8000)
    print("Ollama Exporter running on port 8000")

    # Collect metrics every 15 seconds
    while True:
        collect_metrics()
        time.sleep(15)
EOF

    chmod +x exporter.py

    # Create requirements
    cat > requirements.txt << 'EOF'
prometheus-client==0.19.0
requests==2.31.0
EOF

    pip install -r requirements.txt --break-system-packages 2>/dev/null || \
    pip install -r requirements.txt

    # Create systemd service
    cat > ollama-exporter.service << EOF
[Unit]
Description=Ollama Prometheus Exporter
After=network.target ollama.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$PROJECTS_DIR/ollama-exporter
ExecStart=/usr/bin/python3 $PROJECTS_DIR/ollama-exporter/exporter.py
Restart=always
Environment="OLLAMA_HOST=http://localhost:11434"

[Install]
WantedBy=multi-user.target
EOF

    sudo cp ollama-exporter.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable ollama-exporter
    sudo systemctl start ollama-exporter

    print_status "Ollama Exporter installed and started!"
    print_info "Metrics available at: http://localhost:8000/metrics"
}

create_grafana_dashboards() {
    print_status "Creating Grafana dashboards..."

    cd "$PROJECTS_DIR/monitoring"
    mkdir -p grafana/provisioning/dashboards

    # Create dashboard provisioning config
    cat > grafana/provisioning/dashboards/dashboards.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'Ollama Dashboards'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

    # Create Ollama dashboard JSON (simplified)
    cat > grafana/provisioning/dashboards/ollama-dashboard.json << 'EOF'
{
  "dashboard": {
    "title": "Ollama Monitoring",
    "panels": [
      {
        "title": "Models Loaded",
        "targets": [
          {
            "expr": "ollama_models_loaded"
          }
        ],
        "type": "stat"
      },
      {
        "title": "VRAM Usage",
        "targets": [
          {
            "expr": "ollama_vram_used_bytes / 1024 / 1024 / 1024"
          }
        ],
        "type": "graph"
      },
      {
        "title": "Request Rate",
        "targets": [
          {
            "expr": "rate(ollama_requests_total[5m])"
          }
        ],
        "type": "graph"
      },
      {
        "title": "Response Time",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, ollama_response_time_seconds_bucket)"
          }
        ],
        "type": "graph"
      }
    ]
  }
}
EOF

    print_status "Grafana dashboards created!"
}

export -f install_monitoring
