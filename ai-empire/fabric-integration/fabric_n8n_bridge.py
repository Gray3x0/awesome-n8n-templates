#!/usr/bin/env python3
"""
Fabric n8n Bridge - HTTP API for n8n workflow integration
Part of the AI Empire deployment suite
"""

from flask import Flask, request, jsonify
from fabric_executor import FabricExecutor, VRAMMonitor
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
executor = FabricExecutor()


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'fabric_available': executor.is_fabric_installed(),
        'vram_available': VRAMMonitor.is_vram_available()
    })


@app.route('/patterns', methods=['GET'])
def list_patterns():
    """List available Fabric patterns"""
    patterns = executor.list_patterns()
    return jsonify({
        'patterns': patterns,
        'count': len(patterns)
    })


@app.route('/execute', methods=['POST'])
def execute_pattern():
    """
    Execute a Fabric pattern

    Request body:
    {
        "pattern": "extract_wisdom",
        "input": "Your text here",
        "force_model": "local" or "cloud" (optional)
    }
    """
    try:
        data = request.get_json()

        if not data or 'pattern' not in data or 'input' not in data:
            return jsonify({
                'error': 'Missing required fields: pattern, input'
            }), 400

        pattern = data['pattern']
        input_text = data['input']
        force_model = data.get('force_model')

        # Execute pattern
        result = executor.execute_pattern(
            pattern=pattern,
            input_text=input_text,
            force_model=force_model
        )

        return jsonify(result)

    except Exception as e:
        logger.error(f"Error executing pattern: {e}")
        return jsonify({
            'error': str(e)
        }), 500


@app.route('/vram', methods=['GET'])
def vram_status():
    """Get VRAM status"""
    try:
        vram = VRAMMonitor.get_vram_usage()
        return jsonify({
            'used_mb': vram['used'],
            'total_mb': vram['total'],
            'free_mb': vram['free'],
            'available_for_inference': VRAMMonitor.is_vram_available()
        })
    except Exception as e:
        return jsonify({
            'error': str(e)
        }), 500


@app.route('/cost-estimate', methods=['POST'])
def cost_estimate():
    """
    Estimate cost for a request

    Request body:
    {
        "input": "Your text here",
        "output_tokens": 500 (optional estimate)
    }
    """
    try:
        data = request.get_json()
        input_text = data.get('input', '')
        output_tokens = data.get('output_tokens', 500)

        estimate = executor.estimate_cost(input_text, output_tokens)
        return jsonify(estimate)

    except Exception as e:
        return jsonify({
            'error': str(e)
        }), 500


def main():
    """Run the Flask API server"""
    import argparse

    parser = argparse.ArgumentParser(description='Fabric n8n Bridge API')
    parser.add_argument('--host', default='0.0.0.0', help='Host to bind to')
    parser.add_argument('--port', type=int, default=8080, help='Port to bind to')
    parser.add_argument('--debug', action='store_true', help='Enable debug mode')
    args = parser.parse_args()

    logger.info(f"Starting Fabric n8n Bridge on {args.host}:{args.port}")
    app.run(host=args.host, port=args.port, debug=args.debug)


if __name__ == "__main__":
    main()
