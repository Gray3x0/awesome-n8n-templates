#!/bin/bash

################################################################################
# Performance Tools Installation Module
# Installs: ExLlamaV2, llama.cpp, Benchmarking tools
################################################################################

source "$(dirname "$0")/../install-ollama-suite.sh" 2>/dev/null || true

install_performance_tools() {
    print_header "Installing Performance Optimization Tools"

    install_llamacpp
    install_exllamav2
    install_benchmarking_tools
    create_optimization_scripts

    print_status "Performance tools installed!"
}

install_llamacpp() {
    print_status "Installing llama.cpp (Direct inference)..."

    cd "$PROJECTS_DIR"

    if [ -d "llama.cpp" ]; then
        cd llama.cpp
        git pull
    else
        git clone https://github.com/ggerganov/llama.cpp.git
        cd llama.cpp
    fi

    # Build with CUDA support
    print_status "Building llama.cpp with CUDA..."
    make clean
    make LLAMA_CUDA=1 -j$(nproc)

    # Build Python bindings
    pip install --break-system-packages -e . 2>/dev/null || pip install -e .

    print_status "llama.cpp installed!"
    print_info "Binary: $PROJECTS_DIR/llama.cpp/llama-server"
    print_info "Try: ./llama-server -m model.gguf -ngl 99 -c 4096"
}

install_exllamav2() {
    print_status "Installing ExLlamaV2 (High-performance inference)..."

    cd "$PROJECTS_DIR"

    if [ -d "exllamav2" ]; then
        cd exllamav2
        git pull
    else
        git clone https://github.com/turboderp/exllamav2.git
        cd exllamav2
    fi

    # Install dependencies
    pip install --break-system-packages -r requirements.txt 2>/dev/null || \
    pip install -r requirements.txt

    # Create example script
    cat > ../exllamav2_example.py << 'EOF'
#!/usr/bin/env python3
"""
ExLlamaV2 Example (if you have EXL2 models)
"""

from exllamav2 import ExLlamaV2, ExLlamaV2Config, ExLlamaV2Cache, ExLlamaV2Tokenizer
from exllamav2.generator import ExLlamaV2StreamingGenerator, ExLlamaV2Sampler
import sys

def load_model(model_dir):
    """Load ExLlamaV2 model"""

    # Configure
    config = ExLlamaV2Config()
    config.model_dir = model_dir
    config.prepare()

    # Load model
    model = ExLlamaV2(config)
    cache = ExLlamaV2Cache(model, lazy=True)
    model.load_autosplit(cache)

    # Load tokenizer
    tokenizer = ExLlamaV2Tokenizer(config)

    return model, cache, tokenizer

def generate(model, cache, tokenizer, prompt, max_new_tokens=200):
    """Generate text"""

    # Create generator
    generator = ExLlamaV2StreamingGenerator(model, cache, tokenizer)

    # Configure sampling
    settings = ExLlamaV2Sampler.Settings()
    settings.temperature = 0.85
    settings.top_k = 50
    settings.top_p = 0.8

    # Generate
    generator.warmup()
    generator.begin_stream(prompt, settings)

    generated_text = ""
    for i in range(max_new_tokens):
        chunk, eos, _ = generator.stream()
        generated_text += chunk
        print(chunk, end="", flush=True)

        if eos:
            break

    print()
    return generated_text

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python exllamav2_example.py <model_directory>")
        print("Note: Model must be in EXL2 format")
        sys.exit(1)

    model_dir = sys.argv[1]
    prompt = sys.argv[2] if len(sys.argv) > 2 else "Hello, how are you?"

    print("Loading model...")
    model, cache, tokenizer = load_model(model_dir)

    print(f"\nPrompt: {prompt}\n")
    generate(model, cache, tokenizer, prompt)
EOF

    chmod +x ../exllamav2_example.py

    print_status "ExLlamaV2 installed!"
    print_info "Requires EXL2 format models from HuggingFace"
}

install_benchmarking_tools() {
    print_status "Installing benchmarking tools..."

    # Install ollama-benchmark
    cd "$PROJECTS_DIR"

    pip install --break-system-packages transformers torch 2>/dev/null || \
    pip install transformers torch

    # Create comprehensive benchmark script
    cat > ollama_benchmark.py << 'EOF'
#!/usr/bin/env python3
"""
Comprehensive Ollama Benchmark Suite
Tests: Speed, Memory, Context Length, Quality
"""

import ollama
import time
import psutil
import sys
from datetime import datetime

class OllamaBenchmark:
    def __init__(self, model):
        self.model = model

    def benchmark_speed(self, prompts):
        """Benchmark inference speed"""

        print(f"\n{'='*60}")
        print(f"Speed Benchmark: {self.model}")
        print(f"{'='*60}\n")

        results = []

        for i, prompt in enumerate(prompts, 1):
            print(f"Test {i}/{len(prompts)}: {prompt[:50]}...")

            start = time.time()
            response = ollama.generate(model=self.model, prompt=prompt)
            duration = time.time() - start

            tokens = len(response['response'].split())
            tokens_per_sec = tokens / duration if duration > 0 else 0

            results.append({
                'duration': duration,
                'tokens': tokens,
                'tokens_per_sec': tokens_per_sec
            })

            print(f"  Duration: {duration:.2f}s | Tokens: {tokens} | Speed: {tokens_per_sec:.2f} t/s\n")

        # Summary
        avg_speed = sum(r['tokens_per_sec'] for r in results) / len(results)
        print(f"Average Speed: {avg_speed:.2f} tokens/sec\n")

        return results

    def benchmark_context(self, context_sizes=[512, 1024, 2048, 4096]):
        """Benchmark different context lengths"""

        print(f"\n{'='*60}")
        print(f"Context Length Benchmark: {self.model}")
        print(f"{'='*60}\n")

        base_text = "The quick brown fox jumps over the lazy dog. " * 50

        for size in context_sizes:
            # Create prompt of specific size
            words_needed = size // 5  # Approximate
            prompt = (base_text * (words_needed // len(base_text.split())) + "\n\nSummarize the above text.")

            print(f"Testing context length: ~{size} tokens...")

            try:
                start = time.time()
                response = ollama.generate(
                    model=self.model,
                    prompt=prompt,
                    options={'num_ctx': size}
                )
                duration = time.time() - start

                print(f"  ✓ Success | Duration: {duration:.2f}s\n")

            except Exception as e:
                print(f"  ✗ Failed: {e}\n")

    def benchmark_quality(self, tasks):
        """Benchmark output quality on specific tasks"""

        print(f"\n{'='*60}")
        print(f"Quality Benchmark: {self.model}")
        print(f"{'='*60}\n")

        for task_name, prompt in tasks.items():
            print(f"Task: {task_name}")
            print(f"Prompt: {prompt[:100]}...\n")

            response = ollama.generate(model=self.model, prompt=prompt)

            print(f"Response:\n{response['response'][:300]}...")
            print(f"\n{'-'*60}\n")

    def monitor_resources(self, duration=60):
        """Monitor resource usage during inference"""

        print(f"\n{'='*60}")
        print(f"Resource Monitoring: {self.model}")
        print(f"Duration: {duration}s")
        print(f"{'='*60}\n")

        # Start continuous generation
        import threading

        stop_flag = threading.Event()

        def continuous_generate():
            while not stop_flag.is_set():
                try:
                    ollama.generate(
                        model=self.model,
                        prompt="Generate a paragraph about artificial intelligence."
                    )
                except:
                    pass

        # Start generation thread
        thread = threading.Thread(target=continuous_generate)
        thread.start()

        # Monitor resources
        start = time.time()
        samples = []

        while time.time() - start < duration:
            cpu_percent = psutil.cpu_percent(interval=1)
            memory = psutil.virtual_memory()
            samples.append({
                'cpu': cpu_percent,
                'memory_used_gb': memory.used / (1024**3),
                'memory_percent': memory.percent
            })

        # Stop generation
        stop_flag.set()
        thread.join()

        # Report
        avg_cpu = sum(s['cpu'] for s in samples) / len(samples)
        avg_mem = sum(s['memory_used_gb'] for s in samples) / len(samples)

        print(f"Average CPU Usage: {avg_cpu:.1f}%")
        print(f"Average Memory Usage: {avg_mem:.2f} GB\n")

def main():
    model = sys.argv[1] if len(sys.argv) > 1 else "llama3.2:3b"

    print(f"\n{'#'*60}")
    print(f"# Ollama Benchmark Suite")
    print(f"# Model: {model}")
    print(f"# Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"{'#'*60}\n")

    bench = OllamaBenchmark(model)

    # Speed test
    speed_prompts = [
        "What is machine learning?",
        "Explain quantum computing in simple terms.",
        "Write a short story about a robot.",
    ]
    bench.benchmark_speed(speed_prompts)

    # Context test
    bench.benchmark_context()

    # Quality test
    quality_tasks = {
        "Reasoning": "If all roses are flowers and some flowers fade quickly, can we conclude that some roses fade quickly? Explain.",
        "Coding": "Write a Python function to find the longest palindrome in a string.",
        "Creative": "Write a haiku about programming.",
    }
    bench.benchmark_quality(quality_tasks)

    print(f"\n{'='*60}")
    print("Benchmark Complete!")
    print(f"{'='*60}\n")

if __name__ == "__main__":
    main()
EOF

    chmod +x ollama_benchmark.py

    print_status "Benchmarking tools installed!"
    print_info "Run: python $PROJECTS_DIR/ollama_benchmark.py <model_name>"
}

create_optimization_scripts() {
    print_status "Creating optimization scripts..."

    # Create model quantization script
    cat > "$PROJECTS_DIR/quantize_model.sh" << 'EOF'
#!/bin/bash
# Model Quantization Script for llama.cpp

MODEL_FILE="$1"
OUTPUT_DIR="${2:-./quantized}"
QUANT_TYPES=("Q4_K_M" "Q5_K_M" "Q8_0")

if [ -z "$MODEL_FILE" ]; then
    echo "Usage: ./quantize_model.sh <model.gguf> [output_dir]"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

LLAMACPP_DIR="$HOME/ollama-suite/projects/llama.cpp"

for quant in "${QUANT_TYPES[@]}"; do
    echo "Quantizing to $quant..."
    "$LLAMACPP_DIR/quantize" "$MODEL_FILE" "$OUTPUT_DIR/model-${quant}.gguf" "$quant"
done

echo "Quantization complete! Models saved to: $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR"
EOF

    chmod +x "$PROJECTS_DIR/quantize_model.sh"

    # Create VRAM calculator
    cat > "$PROJECTS_DIR/vram_calculator.py" << 'EOF'
#!/usr/bin/env python3
"""
VRAM Usage Calculator for different models and quantizations
"""

def calculate_vram(params_billions, bits_per_param, context_length=4096):
    """Calculate approximate VRAM usage"""

    # Model weights
    model_vram_gb = (params_billions * 1e9 * bits_per_param) / (8 * 1024**3)

    # KV cache (approximate)
    # layers * 2 (k+v) * heads * head_dim * context * dtype_bytes
    # Simplified: ~100 bytes per token for 7B model
    kv_cache_gb = (context_length * 100 * params_billions / 7) / (1024**3)

    # Overhead (~10%)
    overhead_gb = (model_vram_gb + kv_cache_gb) * 0.1

    total_vram_gb = model_vram_gb + kv_cache_gb + overhead_gb

    return {
        'model_gb': model_vram_gb,
        'kv_cache_gb': kv_cache_gb,
        'overhead_gb': overhead_gb,
        'total_gb': total_vram_gb
    }

def main():
    print("\nVRAM Usage Calculator for GTX 1060 6GB\n")
    print("="*60)

    configs = [
        ("Llama 3.2 3B", 3, 4.0, 8192),  # Q4_K_M
        ("Qwen 2.5 7B", 7, 4.0, 4096),
        ("DeepSeek R1 7B", 7, 4.0, 4096),
        ("Llama 3.1 8B", 8, 4.0, 4096),
        ("Mixtral 8x7B", 47, 4.0, 2048),  # Won't fit!
    ]

    for name, params, bits, context in configs:
        result = calculate_vram(params, bits, context)

        status = "✓ Fits" if result['total_gb'] < 5.5 else "✗ Too large"
        color = "\033[92m" if result['total_gb'] < 5.5 else "\033[91m"
        reset = "\033[0m"

        print(f"\n{name} (Q{int(bits)}, {context} context)")
        print(f"  Model weights: {result['model_gb']:.2f} GB")
        print(f"  KV cache:      {result['kv_cache_gb']:.2f} GB")
        print(f"  Overhead:      {result['overhead_gb']:.2f} GB")
        print(f"  {color}Total:         {result['total_gb']:.2f} GB - {status}{reset}")

    print("\n" + "="*60)
    print("\nRecommendations for GTX 1060 6GB:")
    print("  • Use Q4_K_M or IQ4_XS quantization")
    print("  • Limit context to 4096 tokens")
    print("  • Enable KV cache quantization (q8_0)")
    print("  • Load only one model at a time")
    print("  • Use 3B models for fast inference")
    print("  • Use 7B models for better quality\n")

if __name__ == "__main__":
    main()
EOF

    chmod +x "$PROJECTS_DIR/vram_calculator.py"

    print_status "Optimization scripts created!"
}

export -f install_performance_tools
