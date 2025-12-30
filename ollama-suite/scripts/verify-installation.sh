#!/bin/bash

################################################################################
# Post-Installation Verification Script
# Checks all directories, permissions, services, and configurations
################################################################################

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_pass() {
    echo -e "${GREEN}[✓ PASS]${NC} $1"
}

print_fail() {
    echo -e "${RED}[✗ FAIL]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[! WARN]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i INFO]${NC} $1"
}

print_header() {
    echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  $1"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n"
}

INSTALL_DIR="$HOME/ollama-suite"
ERRORS=0
WARNINGS=0

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                                                                  ║"
echo "║        Ollama Enhancement Suite - Installation Verification     ║"
echo "║                                                                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# ============================================================================
# 1. Check Ollama Installation
# ============================================================================
print_header "Ollama Installation"

if command -v ollama &> /dev/null; then
    VERSION=$(ollama --version 2>&1 | head -1)
    print_pass "Ollama binary found: $VERSION"
else
    print_fail "Ollama binary not found in PATH"
    ((ERRORS++))
fi

if [ -f /usr/local/bin/ollama ]; then
    print_pass "Ollama binary exists at /usr/local/bin/ollama"
else
    print_fail "Ollama binary missing at /usr/local/bin/ollama"
    ((ERRORS++))
fi

# ============================================================================
# 2. Check Ollama Service
# ============================================================================
print_header "Ollama Service"

if systemctl is-active --quiet ollama; then
    print_pass "Ollama service is running"
else
    print_fail "Ollama service is NOT running"
    systemctl status ollama --no-pager -l | head -10
    ((ERRORS++))
fi

if systemctl is-enabled --quiet ollama; then
    print_pass "Ollama service is enabled (will start on boot)"
else
    print_warn "Ollama service is NOT enabled"
    ((WARNINGS++))
fi

# Check systemd override configuration
if [ -f /etc/systemd/system/ollama.service.d/override.conf ]; then
    print_pass "GTX 1060 optimization config found"

    # Verify key optimizations
    if grep -q "OLLAMA_KV_CACHE_TYPE=q8_0" /etc/systemd/system/ollama.service.d/override.conf; then
        print_pass "  KV cache quantization enabled (q8_0)"
    else
        print_warn "  KV cache quantization not configured"
        ((WARNINGS++))
    fi

    if grep -q "OLLAMA_FLASH_ATTENTION=1" /etc/systemd/system/ollama.service.d/override.conf; then
        print_pass "  Flash Attention enabled"
    else
        print_warn "  Flash Attention not configured"
        ((WARNINGS++))
    fi

    if grep -q "OLLAMA_MAX_LOADED_MODELS=1" /etc/systemd/system/ollama.service.d/override.conf; then
        print_pass "  Single model loading enforced (prevents OOM)"
    else
        print_warn "  Multiple model loading allowed (may cause OOM)"
        ((WARNINGS++))
    fi
else
    print_fail "GTX 1060 optimization config missing"
    ((ERRORS++))
fi

# ============================================================================
# 3. Check Port 11434
# ============================================================================
print_header "Network & Port"

if sudo lsof -i:11434 >/dev/null 2>&1; then
    PROCESS=$(sudo lsof -i:11434 | grep LISTEN | awk '{print $1}' | head -1)
    if [ "$PROCESS" = "ollama" ]; then
        print_pass "Port 11434 is listening (ollama)"
    else
        print_fail "Port 11434 is in use by: $PROCESS (should be ollama)"
        ((ERRORS++))
    fi
else
    print_fail "Port 11434 is NOT listening"
    ((ERRORS++))
fi

# Test API endpoint
if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    print_pass "Ollama API is responding"
else
    print_fail "Ollama API is NOT responding at http://localhost:11434"
    ((ERRORS++))
fi

# ============================================================================
# 4. Check GPU Access
# ============================================================================
print_header "GPU Configuration"

if command -v nvidia-smi &> /dev/null; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
    GPU_VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1)

    if [ -n "$GPU_NAME" ]; then
        print_pass "NVIDIA GPU detected: $GPU_NAME"
        print_info "  VRAM: ${GPU_VRAM}MB"

        if [ "$GPU_VRAM" -lt 6000 ]; then
            print_warn "  VRAM less than 6GB - may struggle with 7B models"
            ((WARNINGS++))
        fi
    else
        print_fail "Could not detect GPU with nvidia-smi"
        ((ERRORS++))
    fi
else
    print_fail "nvidia-smi not found"
    ((ERRORS++))
fi

# Check CUDA
if [ -d /usr/local/cuda ]; then
    print_pass "CUDA installation found"
    if command -v nvcc &> /dev/null; then
        CUDA_VERSION=$(nvcc --version | grep "release" | awk '{print $5}' | tr -d ',')
        print_info "  CUDA version: $CUDA_VERSION"
    fi
else
    print_warn "CUDA not found at /usr/local/cuda"
    ((WARNINGS++))
fi

# ============================================================================
# 5. Check Directory Structure
# ============================================================================
print_header "Directory Structure"

REQUIRED_DIRS=(
    "$INSTALL_DIR"
    "$INSTALL_DIR/projects"
    "$INSTALL_DIR/data"
    "$INSTALL_DIR/logs"
    "$INSTALL_DIR/backups"
    "$INSTALL_DIR/configs"
    "$INSTALL_DIR/scripts"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        print_pass "Directory exists: $dir"
    else
        print_fail "Directory missing: $dir"
        ((ERRORS++))
    fi
done

# Check Ollama data directory
if [ -d ~/.ollama ]; then
    print_pass "Ollama user data directory exists: ~/.ollama"

    if [ -d ~/.ollama/models ]; then
        MODEL_COUNT=$(ls -1 ~/.ollama/models/manifests/registry.ollama.ai/library 2>/dev/null | wc -l)
        if [ "$MODEL_COUNT" -gt 0 ]; then
            print_pass "  $MODEL_COUNT model(s) installed"
        else
            print_warn "  No models installed yet"
            ((WARNINGS++))
        fi
    fi
else
    print_warn "Ollama user data directory not created yet"
    ((WARNINGS++))
fi

# ============================================================================
# 6. Check Permissions
# ============================================================================
print_header "Permissions"

# Check script executability
SCRIPTS=(
    "$INSTALL_DIR/install-ollama-suite.sh"
    "$INSTALL_DIR/uninstall-ollama.sh"
    "$INSTALL_DIR/scripts/backup.sh"
    "$INSTALL_DIR/scripts/update-all.sh"
)

for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            print_pass "Script is executable: $(basename $script)"
        else
            print_fail "Script is NOT executable: $(basename $script)"
            ((ERRORS++))
        fi
    fi
done

# Check ollama user
if id ollama &>/dev/null; then
    print_pass "Ollama user exists"

    # Check group memberships
    if groups ollama | grep -q "render"; then
        print_pass "  ollama user in 'render' group"
    else
        print_warn "  ollama user NOT in 'render' group"
        ((WARNINGS++))
    fi

    if groups ollama | grep -q "video"; then
        print_pass "  ollama user in 'video' group"
    else
        print_warn "  ollama user NOT in 'video' group"
        ((WARNINGS++))
    fi
else
    print_fail "Ollama user does not exist"
    ((ERRORS++))
fi

# Check current user in ollama group
if groups | grep -q "ollama"; then
    print_pass "Current user is in 'ollama' group"
else
    print_warn "Current user is NOT in 'ollama' group (may need logout/login)"
    ((WARNINGS++))
fi

# ============================================================================
# 7. Check Docker
# ============================================================================
print_header "Docker Configuration"

if command -v docker &> /dev/null; then
    print_pass "Docker is installed: $(docker --version)"

    if docker ps >/dev/null 2>&1; then
        print_pass "Docker daemon is running"

        # Check for NVIDIA Docker runtime
        if docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi >/dev/null 2>&1; then
            print_pass "NVIDIA Docker runtime is working"
        else
            print_warn "NVIDIA Docker runtime may not be configured"
            ((WARNINGS++))
        fi

        # Check running Ollama containers
        OLLAMA_CONTAINERS=$(docker ps --filter "name=ollama" --format "{{.Names}}" 2>/dev/null)
        if [ -n "$OLLAMA_CONTAINERS" ]; then
            print_info "Running Ollama-related containers:"
            echo "$OLLAMA_CONTAINERS" | while read container; do
                print_info "  - $container"
            done
        fi
    else
        print_fail "Docker daemon is NOT running"
        ((ERRORS++))
    fi

    # Check Docker Compose
    if docker compose version >/dev/null 2>&1; then
        print_pass "Docker Compose is available"
    else
        print_warn "Docker Compose is NOT available"
        ((WARNINGS++))
    fi
else
    print_fail "Docker is NOT installed"
    ((ERRORS++))
fi

# ============================================================================
# 8. Check Python Environment
# ============================================================================
print_header "Python Environment"

if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1)
    print_pass "Python3 found: $PYTHON_VERSION"

    # Check key Python packages
    PACKAGES=("ollama" "langchain" "llama-index" "crewai")

    for pkg in "${PACKAGES[@]}"; do
        if python3 -c "import $pkg" 2>/dev/null; then
            VERSION=$(python3 -c "import $pkg; print($pkg.__version__)" 2>/dev/null || echo "unknown")
            print_pass "  $pkg installed (v$VERSION)"
        else
            print_info "  $pkg not installed (optional)"
        fi
    done
else
    print_fail "Python3 NOT found"
    ((ERRORS++))
fi

if command -v pip3 &> /dev/null; then
    print_pass "pip3 is available"
else
    print_warn "pip3 NOT found"
    ((WARNINGS++))
fi

# ============================================================================
# 9. Check Models
# ============================================================================
print_header "Installed Models"

if command -v ollama &> /dev/null; then
    MODELS=$(ollama list 2>/dev/null | tail -n +2)

    if [ -n "$MODELS" ]; then
        print_pass "Models are installed:"
        echo "$MODELS" | while IFS= read -r line; do
            MODEL_NAME=$(echo "$line" | awk '{print $1}')
            MODEL_SIZE=$(echo "$line" | awk '{print $2}')
            print_info "  - $MODEL_NAME ($MODEL_SIZE)"
        done
    else
        print_warn "No models installed yet"
        print_info "  Run: ollama pull llama3.2:3b"
        ((WARNINGS++))
    fi
fi

# ============================================================================
# 10. Test Basic Functionality
# ============================================================================
print_header "Functional Tests"

# Test simple query
if command -v ollama &> /dev/null && ollama list 2>/dev/null | grep -q ":"; then
    print_info "Testing inference (this may take a moment)..."

    # Get first available model
    FIRST_MODEL=$(ollama list 2>/dev/null | tail -n +2 | head -1 | awk '{print $1}')

    if [ -n "$FIRST_MODEL" ]; then
        TEST_OUTPUT=$(timeout 30 ollama run "$FIRST_MODEL" "Say only the word 'working'" 2>&1 | head -5)

        if [ $? -eq 0 ]; then
            print_pass "Inference test successful with $FIRST_MODEL"
        else
            print_fail "Inference test failed"
            print_info "  Error: $TEST_OUTPUT"
            ((ERRORS++))
        fi
    fi
else
    print_warn "Skipping inference test (no models installed)"
    ((WARNINGS++))
fi

# ============================================================================
# SUMMARY
# ============================================================================
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                     VERIFICATION SUMMARY                         ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    print_pass "ALL CHECKS PASSED! ✨"
    echo ""
    print_info "Your Ollama installation is perfect and ready to use!"
    echo ""
    print_info "Next steps:"
    echo "  1. Pull models: ollama pull llama3.2:3b"
    echo "  2. Access Open WebUI: http://localhost:3000"
    echo "  3. Try the examples in ~/ollama-suite/projects/"
    echo ""
    exit 0
elif [ $ERRORS -eq 0 ]; then
    print_warn "Passed with $WARNINGS warning(s)"
    echo ""
    print_info "Your installation works but has minor issues."
    print_info "Review the warnings above and fix if needed."
    echo ""
    exit 0
else
    print_fail "FAILED with $ERRORS error(s) and $WARNINGS warning(s)"
    echo ""
    print_info "Critical issues found. Please fix the errors above."
    print_info "Run this script again after fixes: ./scripts/verify-installation.sh"
    echo ""
    exit 1
fi
