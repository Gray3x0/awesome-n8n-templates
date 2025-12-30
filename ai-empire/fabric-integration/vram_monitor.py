#!/usr/bin/env python3
"""
VRAM Monitor - Standalone GPU memory monitoring daemon
Part of the AI Empire deployment suite
"""

import subprocess
import time
import logging
import signal
from typing import Dict
from datetime import datetime

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class VRAMMonitorDaemon:
    """
    Daemon that monitors VRAM usage and logs statistics
    """

    def __init__(self, check_interval: int = 30, log_file: str = '/var/log/vram_monitor.log'):
        self.check_interval = check_interval
        self.log_file = log_file
        self.running = True

        # Setup signal handlers
        signal.signal(signal.SIGTERM, self._handle_signal)
        signal.signal(signal.SIGINT, self._handle_signal)

        # Setup file logging
        file_handler = logging.FileHandler(log_file)
        file_handler.setFormatter(logging.Formatter(
            '%(asctime)s - %(levelname)s - %(message)s'
        ))
        logger.addHandler(file_handler)

    def _handle_signal(self, signum, frame):
        """Handle shutdown signals"""
        logger.info(f"Received signal {signum}, shutting down...")
        self.running = False

    def get_vram_usage(self) -> Dict[str, int]:
        """Get current VRAM usage in MB"""
        try:
            result = subprocess.run(
                ['nvidia-smi', '--query-gpu=memory.used,memory.total,temperature.gpu,utilization.gpu',
                 '--format=csv,noheader,nounits'],
                capture_output=True,
                text=True,
                check=True,
                timeout=5
            )

            values = result.stdout.strip().split(',')
            used = int(values[0].strip())
            total = int(values[1].strip())
            temp = int(values[2].strip())
            util = int(values[3].strip())

            return {
                'used_mb': used,
                'total_mb': total,
                'free_mb': total - used,
                'temperature_c': temp,
                'utilization_pct': util,
                'timestamp': datetime.now().isoformat()
            }

        except Exception as e:
            logger.error(f"Error getting VRAM usage: {e}")
            return {}

    def check_thresholds(self, usage: Dict):
        """Check for concerning VRAM/temperature thresholds"""
        if not usage:
            return

        # Warning thresholds
        if usage.get('temperature_c', 0) > 80:
            logger.warning(f"GPU temperature high: {usage['temperature_c']}°C")

        if usage.get('utilization_pct', 0) > 95:
            logger.warning(f"GPU utilization high: {usage['utilization_pct']}%")

        used_pct = (usage.get('used_mb', 0) / usage.get('total_mb', 1)) * 100
        if used_pct > 90:
            logger.warning(f"VRAM usage high: {used_pct:.1f}% ({usage['used_mb']}MB/{usage['total_mb']}MB)")

    def run(self):
        """Main daemon loop"""
        logger.info("VRAM Monitor daemon started")
        logger.info(f"Check interval: {self.check_interval} seconds")
        logger.info(f"Log file: {self.log_file}")

        while self.running:
            try:
                usage = self.get_vram_usage()

                if usage:
                    logger.info(
                        f"VRAM: {usage['used_mb']}/{usage['total_mb']}MB "
                        f"({usage['free_mb']}MB free) | "
                        f"GPU: {usage['utilization_pct']}% | "
                        f"Temp: {usage['temperature_c']}°C"
                    )

                    self.check_thresholds(usage)

                # Wait for next check
                for _ in range(self.check_interval):
                    if not self.running:
                        break
                    time.sleep(1)

            except Exception as e:
                logger.error(f"Error in monitor loop: {e}")
                time.sleep(60)

        logger.info("VRAM Monitor daemon stopped")


def main():
    """Start the daemon"""
    import argparse

    parser = argparse.ArgumentParser(description='VRAM monitoring daemon')
    parser.add_argument('--interval', type=int, default=30,
                       help='Check interval in seconds (default: 30)')
    parser.add_argument('--log-file', default='/var/log/vram_monitor.log',
                       help='Log file path')
    args = parser.parse_args()

    daemon = VRAMMonitorDaemon(
        check_interval=args.interval,
        log_file=args.log_file
    )
    daemon.run()


if __name__ == "__main__":
    main()
