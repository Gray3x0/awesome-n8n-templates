#!/usr/bin/env python3
"""
Fabric Pattern Executor with VRAM Monitoring and LiteLLM Integration
Intelligently routes requests based on GPU availability
"""

import subprocess
import os
import json
import logging
from typing import Optional, Dict, Any
import requests

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class VRAMMonitor:
    """Monitor GPU VRAM usage"""

    @staticmethod
    def get_vram_usage() -> Dict[str, int]:
        """Get current VRAM usage in MB"""
        try:
            result = subprocess.run(
                ['nvidia-smi', '--query-gpu=memory.used,memory.total',
                 '--format=csv,noheader,nounits'],
                capture_output=True, text=True, check=True
            )
            used, total = map(int, result.stdout.strip().split(','))
            return {'used': used, 'total': total, 'free': total - used}
        except Exception as e:
            logger.error(f"Error getting VRAM: {e}")
            return {'used': 0, 'total': 6144, 'free': 0}

    @staticmethod
    def is_vram_available(required_mb: int = 4500) -> bool:
        """Check if enough VRAM is available for local inference"""
        vram = VRAMMonitor.get_vram_usage()
        available = vram['free'] >= required_mb
        logger.info(f"VRAM: {vram['free']}MB free / {vram['total']}MB total - "
                   f"{'✓ OK' if available else '✗ BUSY'}")
        return available


class FabricExecutor:
    """
    Execute Fabric patterns with intelligent model routing
    Routes to local DeepSeek R1-8B when VRAM available, Claude API otherwise
    """

    def __init__(self, litellm_url: str = "http://localhost:4000"):
        self.litellm_url = litellm_url
        self.vram_monitor = VRAMMonitor()
        self.fabric_bin = self._find_fabric()

    def _find_fabric(self) -> str:
        """Locate Fabric binary"""
        try:
            result = subprocess.run(['which', 'fabric'], capture_output=True, text=True)
            if result.returncode == 0:
                return result.stdout.strip()
        except Exception:
            pass
        return os.path.expanduser("~/go/bin/fabric")

    def execute_pattern(self, pattern: str, input_text: str,
                       force_model: Optional[str] = None) -> Dict[str, Any]:
        """
        Execute Fabric pattern with intelligent routing

        Args:
            pattern: Fabric pattern name (e.g., 'extract_wisdom', 'summarize')
            input_text: Input text to process
            force_model: Optional model override ('local', 'claude', or None for auto)

        Returns:
            Dict with output, model_used, cached, and cost
        """
        # Determine model
        if force_model:
            use_local = force_model == 'local'
        else:
            use_local = self.vram_monitor.is_vram_available()

        model = "ollama:deepseek-r1:8b" if use_local else "claude-3-5-sonnet-20241022"

        logger.info(f"Executing pattern '{pattern}' with {model}")

        try:
            # Execute Fabric with specified model
            env = os.environ.copy()
            env['FABRIC_MODEL'] = model
            env['LITELLM_PROXY'] = self.litellm_url

            process = subprocess.run(
                [self.fabric_bin, '--pattern', pattern],
                input=input_text.encode(),
                capture_output=True,
                timeout=120,
                env=env
            )

            if process.returncode == 0:
                output = process.stdout.decode()
                logger.info(f"✓ Pattern executed successfully ({len(output)} chars)")

                return {
                    'success': True,
                    'output': output,
                    'model_used': model,
                    'pattern': pattern,
                    'input_length': len(input_text),
                    'output_length': len(output),
                    'cost_estimate': 0 if use_local else self._estimate_cost(input_text, output)
                }
            else:
                error = process.stderr.decode()
                logger.error(f"✗ Pattern execution failed: {error}")
                return {
                    'success': False,
                    'error': error,
                    'model_used': model,
                    'pattern': pattern
                }

        except subprocess.TimeoutExpired:
            logger.error("✗ Pattern execution timed out")
            return {'success': False, 'error': 'Execution timed out'}
        except Exception as e:
            logger.error(f"✗ Execution error: {e}")
            return {'success': False, 'error': str(e)}

    def _estimate_cost(self, input_text: str, output: str) -> float:
        """Estimate API cost (rough approximation)"""
        input_tokens = len(input_text.split()) * 1.3  # Rough token estimate
        output_tokens = len(output.split()) * 1.3

        # Claude pricing (approximate)
        cost_per_1k_input = 0.003
        cost_per_1k_output = 0.015

        return (input_tokens / 1000 * cost_per_1k_input +
                output_tokens / 1000 * cost_per_1k_output)

    def list_patterns(self) -> list:
        """List available Fabric patterns"""
        try:
            result = subprocess.run(
                [self.fabric_bin, '--listpatterns'],
                capture_output=True, text=True, check=True
            )
            patterns = [p.strip() for p in result.stdout.split('\n') if p.strip()]
            return patterns
        except Exception as e:
            logger.error(f"Error listing patterns: {e}")
            return []

    def test_connectivity(self) -> Dict[str, bool]:
        """Test connections to all components"""
        results = {}

        # Test Fabric
        try:
            subprocess.run([self.fabric_bin, '--version'],
                         capture_output=True, check=True, timeout=5)
            results['fabric'] = True
        except Exception:
            results['fabric'] = False

        # Test LiteLLM
        try:
            response = requests.get(f"{self.litellm_url}/health", timeout=5)
            results['litellm'] = response.status_code == 200
        except Exception:
            results['litellm'] = False

        # Test Ollama
        try:
            response = requests.get("http://localhost:11434/api/tags", timeout=5)
            results['ollama'] = response.status_code == 200
        except Exception:
            results['ollama'] = False

        # Test GPU
        results['gpu'] = self.vram_monitor.get_vram_usage()['total'] > 0

        return results


def main():
    """CLI interface"""
    import sys

    if len(sys.argv) < 3:
        print("Usage: fabric_executor.py <pattern> <input_file>")
        print("       fabric_executor.py test")
        print("       fabric_executor.py list")
        sys.exit(1)

    executor = FabricExecutor()

    if sys.argv[1] == "test":
        results = executor.test_connectivity()
        print("\n🔍 Connectivity Test:")
        for component, status in results.items():
            print(f"  {'✓' if status else '✗'} {component}: {'OK' if status else 'FAILED'}")
        sys.exit(0 if all(results.values()) else 1)

    elif sys.argv[1] == "list":
        patterns = executor.list_patterns()
        print(f"\n📋 Available Patterns ({len(patterns)}):\n")
        for p in patterns:
            print(f"  - {p}")
        sys.exit(0)

    # Execute pattern
    pattern = sys.argv[1]
    input_file = sys.argv[2]

    try:
        with open(input_file, 'r') as f:
            input_text = f.read()
    except Exception as e:
        print(f"Error reading input file: {e}")
        sys.exit(1)

    result = executor.execute_pattern(pattern, input_text)

    if result['success']:
        print(result['output'])
        print(f"\n✓ Used: {result['model_used']}", file=sys.stderr)
        if result.get('cost_estimate', 0) > 0:
            print(f"💰 Cost: ${result['cost_estimate']:.4f}", file=sys.stderr)
    else:
        print(f"Error: {result['error']}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
