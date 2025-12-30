#!/usr/bin/env python3
"""
Cloudflare Automation Daemon - Auto-sync DNS and Service Discovery
Part of the AI Empire deployment suite
"""

import time
import logging
import signal
import sys
from cloudflare_manager import CloudflareManager
from typing import Dict, Set

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class CloudflareDaemon:
    """
    Daemon that monitors services and automatically syncs DNS records
    """

    def __init__(self, sync_interval: int = 300):
        self.cf = CloudflareManager()
        self.sync_interval = sync_interval  # seconds
        self.running = True
        self.known_services: Set[str] = set()

        # Setup signal handlers
        signal.signal(signal.SIGTERM, self._handle_signal)
        signal.signal(signal.SIGINT, self._handle_signal)

    def _handle_signal(self, signum, frame):
        """Handle shutdown signals"""
        logger.info(f"Received signal {signum}, shutting down...")
        self.running = False

    def discover_local_services(self) -> Dict[str, int]:
        """Discover services running on localhost"""
        import subprocess

        services = {}

        # Common service ports to check
        known_ports = {
            11434: 'ollama',
            4000: 'litellm',
            5678: 'n8n',
            3003: 'langfuse',
            3004: 'grafana',
            5432: 'postgresql',
            6379: 'redis'
        }

        try:
            # Check listening ports
            result = subprocess.run(
                ['ss', '-tlnp'],
                capture_output=True,
                text=True,
                timeout=10
            )

            for port, name in known_ports.items():
                if f':{port}' in result.stdout:
                    services[name] = port
                    logger.debug(f"Discovered service: {name} on port {port}")

        except Exception as e:
            logger.error(f"Error discovering services: {e}")

        return services

    def get_public_ip(self) -> str:
        """Get public IP address"""
        import requests

        try:
            response = requests.get('https://api.ipify.org', timeout=10)
            if response.status_code == 200:
                return response.text.strip()
        except Exception as e:
            logger.error(f"Error getting public IP: {e}")

        return "0.0.0.0"

    def sync_dns_records(self):
        """Sync DNS records with discovered services"""
        public_ip = self.get_public_ip()
        services = self.discover_local_services()

        logger.info(f"Syncing {len(services)} service(s) to DNS (IP: {public_ip})")

        for service_name, port in services.items():
            # Check if DNS record exists
            existing_records = self.cf.get_dns_records(name=f"{service_name}.{self.cf.domain}")

            if existing_records:
                # Update existing record
                record = existing_records[0]
                if record['content'] != public_ip:
                    self.cf.update_dns_record(
                        record_id=record['id'],
                        content=public_ip,
                        proxied=True
                    )
                    logger.info(f"✓ Updated DNS: {service_name}.{self.cf.domain} -> {public_ip}")
                else:
                    logger.debug(f"DNS record up to date: {service_name}")
            else:
                # Create new record
                self.cf.create_dns_record(
                    name=service_name,
                    type='A',
                    content=public_ip,
                    proxied=True
                )
                logger.info(f"✓ Created DNS: {service_name}.{self.cf.domain} -> {public_ip}")

            self.known_services.add(service_name)

    def cleanup_stale_records(self):
        """Remove DNS records for services that no longer exist"""
        current_services = set(self.discover_local_services().keys())
        stale_services = self.known_services - current_services

        for service_name in stale_services:
            records = self.cf.get_dns_records(name=f"{service_name}.{self.cf.domain}")
            for record in records:
                logger.info(f"Removing stale DNS record: {service_name}.{self.cf.domain}")
                self.cf.delete_dns_record(record['id'])

            self.known_services.remove(service_name)

    def run(self):
        """Main daemon loop"""
        logger.info("Cloudflare DNS sync daemon started")
        logger.info(f"Sync interval: {self.sync_interval} seconds")

        # Initial sync
        if not self.cf.validate_credentials():
            logger.error("Cloudflare credentials invalid - daemon exiting")
            return

        while self.running:
            try:
                self.sync_dns_records()
                self.cleanup_stale_records()

                # Wait for next sync
                for _ in range(self.sync_interval):
                    if not self.running:
                        break
                    time.sleep(1)

            except Exception as e:
                logger.error(f"Error in daemon loop: {e}")
                time.sleep(60)  # Wait before retry

        logger.info("Cloudflare DNS sync daemon stopped")


def main():
    """Start the daemon"""
    import argparse

    parser = argparse.ArgumentParser(description='Cloudflare DNS sync daemon')
    parser.add_argument('--interval', type=int, default=300,
                       help='Sync interval in seconds (default: 300)')
    args = parser.parse_args()

    daemon = CloudflareDaemon(sync_interval=args.interval)
    daemon.run()


if __name__ == "__main__":
    main()
