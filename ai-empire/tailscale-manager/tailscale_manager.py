#!/usr/bin/env python3
"""
Tailscale Manager - VPN Mesh Network Automation
Part of the AI Empire deployment suite
"""

import os
import requests
import json
import subprocess
import logging
from typing import Optional, Dict, List
from datetime import datetime

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class TailscaleManager:
    """
    Complete Tailscale API management for VPN mesh networking,
    device management, and secure service access
    """

    def __init__(self):
        self.api_key = os.getenv('TAILSCALE_API_KEY')
        self.tailnet = os.getenv('TAILSCALE_TAILNET', 'default')
        self.base_url = "https://api.tailscale.com/api/v2"
        self.headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }

        if not self.api_key:
            logger.warning("TAILSCALE_API_KEY not set - API features will be limited")

    def validate_credentials(self) -> bool:
        """Validate Tailscale API credentials"""
        if not self.api_key:
            logger.error("✗ API key not configured")
            return False

        try:
            response = requests.get(
                f"{self.base_url}/tailnet/{self.tailnet}/devices",
                headers=self.headers,
                timeout=10
            )
            if response.status_code == 200:
                devices = response.json()['devices']
                logger.info(f"✓ Authenticated - {len(devices)} device(s) in tailnet")
                return True
            else:
                logger.error(f"✗ Authentication failed: {response.text}")
                return False
        except Exception as e:
            logger.error(f"✗ Validation error: {e}")
            return False

    def get_devices(self) -> List[Dict]:
        """Get all devices in the tailnet"""
        if not self.api_key:
            return []

        try:
            response = requests.get(
                f"{self.base_url}/tailnet/{self.tailnet}/devices",
                headers=self.headers,
                timeout=10
            )
            if response.status_code == 200:
                return response.json()['devices']
        except Exception as e:
            logger.error(f"Error getting devices: {e}")
        return []

    def get_device_routes(self, device_id: str) -> List[str]:
        """Get advertised routes for a device"""
        devices = self.get_devices()
        for device in devices:
            if device['id'] == device_id:
                return device.get('advertisedRoutes', [])
        return []

    def authorize_device(self, device_id: str) -> bool:
        """Authorize a device in the tailnet"""
        if not self.api_key:
            return False

        try:
            response = requests.post(
                f"{self.base_url}/device/{device_id}/authorized",
                headers=self.headers,
                json={"authorized": True},
                timeout=10
            )
            if response.status_code == 200:
                logger.info(f"✓ Authorized device {device_id}")
                return True
            else:
                logger.error(f"✗ Failed to authorize device: {response.text}")
        except Exception as e:
            logger.error(f"Error authorizing device: {e}")
        return False

    def set_device_tags(self, device_id: str, tags: List[str]) -> bool:
        """Set tags for a device"""
        if not self.api_key:
            return False

        # Ensure tags start with "tag:"
        formatted_tags = [t if t.startswith('tag:') else f'tag:{t}' for t in tags]

        try:
            response = requests.post(
                f"{self.base_url}/device/{device_id}/tags",
                headers=self.headers,
                json={"tags": formatted_tags},
                timeout=10
            )
            if response.status_code == 200:
                logger.info(f"✓ Set tags for device {device_id}: {formatted_tags}")
                return True
            else:
                logger.error(f"✗ Failed to set tags: {response.text}")
        except Exception as e:
            logger.error(f"Error setting tags: {e}")
        return False

    def get_local_status(self) -> Dict:
        """Get local Tailscale status via CLI"""
        try:
            result = subprocess.run(
                ['tailscale', 'status', '--json'],
                capture_output=True,
                text=True,
                check=True,
                timeout=10
            )
            return json.loads(result.stdout)
        except subprocess.CalledProcessError as e:
            logger.error(f"Error getting local status: {e}")
            return {}
        except FileNotFoundError:
            logger.error("Tailscale CLI not found")
            return {}

    def is_connected(self) -> bool:
        """Check if Tailscale is connected"""
        status = self.get_local_status()
        return status.get('BackendState') == 'Running'

    def get_tailscale_ip(self) -> Optional[str]:
        """Get the local Tailscale IP address"""
        status = self.get_local_status()
        self_peer = status.get('Self', {})
        tailscale_ips = self_peer.get('TailscaleIPs', [])
        return tailscale_ips[0] if tailscale_ips else None

    def up(self, advertise_routes: Optional[List[str]] = None,
           accept_routes: bool = True, accept_dns: bool = True) -> bool:
        """Bring up Tailscale with optional route advertisement"""
        cmd = ['sudo', 'tailscale', 'up']

        if advertise_routes:
            cmd.extend(['--advertise-routes', ','.join(advertise_routes)])

        if accept_routes:
            cmd.append('--accept-routes')

        if accept_dns:
            cmd.append('--accept-dns')

        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            if result.returncode == 0:
                logger.info("✓ Tailscale is up")
                return True
            else:
                logger.error(f"✗ Failed to bring up Tailscale: {result.stderr}")
                return False
        except Exception as e:
            logger.error(f"Error bringing up Tailscale: {e}")
            return False

    def down(self) -> bool:
        """Bring down Tailscale"""
        try:
            result = subprocess.run(
                ['sudo', 'tailscale', 'down'],
                capture_output=True,
                text=True,
                timeout=10
            )
            if result.returncode == 0:
                logger.info("✓ Tailscale is down")
                return True
            else:
                logger.error(f"✗ Failed to bring down Tailscale: {result.stderr}")
                return False
        except Exception as e:
            logger.error(f"Error bringing down Tailscale: {e}")
            return False

    def enable_exit_node(self, exit_node_ip: str) -> bool:
        """Use another device as an exit node"""
        try:
            result = subprocess.run(
                ['sudo', 'tailscale', 'up', '--exit-node', exit_node_ip],
                capture_output=True,
                text=True,
                timeout=30
            )
            if result.returncode == 0:
                logger.info(f"✓ Using {exit_node_ip} as exit node")
                return True
            else:
                logger.error(f"✗ Failed to set exit node: {result.stderr}")
                return False
        except Exception as e:
            logger.error(f"Error setting exit node: {e}")
            return False

    def disable_exit_node(self) -> bool:
        """Disable exit node routing"""
        try:
            result = subprocess.run(
                ['sudo', 'tailscale', 'up', '--exit-node='],
                capture_output=True,
                text=True,
                timeout=30
            )
            if result.returncode == 0:
                logger.info("✓ Exit node disabled")
                return True
            else:
                logger.error(f"✗ Failed to disable exit node: {result.stderr}")
                return False
        except Exception as e:
            logger.error(f"Error disabling exit node: {e}")
            return False

    def configure_split_dns(self, domain: str, nameservers: List[str]) -> bool:
        """Configure split DNS for a domain"""
        try:
            result = subprocess.run(
                ['sudo', 'tailscale', 'set', '--nameserver', ','.join(nameservers),
                 '--accept-dns'],
                capture_output=True,
                text=True,
                timeout=10
            )
            if result.returncode == 0:
                logger.info(f"✓ Configured split DNS for {domain}")
                return True
            else:
                logger.error(f"✗ Failed to configure DNS: {result.stderr}")
                return False
        except Exception as e:
            logger.error(f"Error configuring split DNS: {e}")
            return False

    def get_peer_list(self) -> List[Dict]:
        """Get list of all peers in the tailnet"""
        status = self.get_local_status()
        peers = []

        for peer_id, peer_info in status.get('Peer', {}).items():
            peers.append({
                'id': peer_id,
                'hostname': peer_info.get('HostName', 'unknown'),
                'ip': peer_info.get('TailscaleIPs', ['unknown'])[0],
                'online': peer_info.get('Online', False),
                'last_seen': peer_info.get('LastSeen', 'unknown')
            })

        return peers

    def export_status(self, output_file: str = "tailscale_status.json") -> bool:
        """Export Tailscale status to file"""
        status = self.get_local_status()
        devices = self.get_devices() if self.api_key else []

        export_data = {
            'local_status': status,
            'devices': devices,
            'exported_at': datetime.now().isoformat()
        }

        try:
            with open(output_file, 'w') as f:
                json.dump(export_data, f, indent=2)
            logger.info(f"✓ Exported status to {output_file}")
            return True
        except Exception as e:
            logger.error(f"Error exporting status: {e}")
            return False


def main():
    """CLI interface for Tailscale manager"""
    import sys

    if len(sys.argv) < 2:
        print("Usage: tailscale_manager.py <command> [args]")
        print("Commands: validate, status, devices, up, down, peers, export")
        sys.exit(1)

    ts = TailscaleManager()
    command = sys.argv[1]

    if command == "validate":
        ts.validate_credentials()
    elif command == "status":
        status = ts.get_local_status()
        print(json.dumps(status, indent=2))
    elif command == "devices":
        devices = ts.get_devices()
        for d in devices:
            print(f"{d['hostname']:20} {d.get('addresses', ['unknown'])[0]:15} "
                  f"{'[ONLINE]' if d.get('online') else '[OFFLINE]'}")
    elif command == "up":
        ts.up()
    elif command == "down":
        ts.down()
    elif command == "peers":
        peers = ts.get_peer_list()
        for p in peers:
            print(f"{p['hostname']:20} {p['ip']:15} {'[ONLINE]' if p['online'] else '[OFFLINE]'}")
    elif command == "export":
        filename = sys.argv[2] if len(sys.argv) > 2 else "tailscale_status.json"
        ts.export_status(filename)
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)


if __name__ == "__main__":
    main()
