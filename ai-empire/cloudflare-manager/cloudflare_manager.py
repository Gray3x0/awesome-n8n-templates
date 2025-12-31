#!/usr/bin/env python3
"""
Cloudflare Manager - Automated DNS and Security Management
Part of the AI Empire deployment suite
"""

import os
import requests
import json
import time
import logging
from typing import Optional, Dict, List
from datetime import datetime

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class CloudflareManager:
    """
    Complete Cloudflare API management for automated domain routing,
    DNS records, security rules, and DDoS protection
    """

    def __init__(self):
        self.api_token = os.getenv('CLOUDFLARE_API_TOKEN')
        self.zone_id = os.getenv('CLOUDFLARE_ZONE_ID')
        self.account_id = os.getenv('CLOUDFLARE_ACCOUNT_ID')
        self.domain = os.getenv('DOMAIN_NAME')
        self.base_url = "https://api.cloudflare.com/client/v4"
        self.headers = {
            "Authorization": f"Bearer {self.api_token}",
            "Content-Type": "application/json"
        }

        if not all([self.api_token, self.zone_id, self.domain]):
            raise ValueError("Missing required Cloudflare credentials in environment")

    def validate_credentials(self) -> bool:
        """Validate Cloudflare API credentials"""
        try:
            response = requests.get(f"{self.base_url}/user", headers=self.headers, timeout=10)
            if response.status_code == 200:
                user_data = response.json()['result']
                logger.info(f"✓ Authenticated as: {user_data.get('email')}")
                return True
            else:
                logger.error(f"✗ Authentication failed: {response.text}")
                return False
        except Exception as e:
            logger.error(f"✗ Validation error: {e}")
            return False

    def get_dns_records(self, name: Optional[str] = None) -> List[Dict]:
        """Get all DNS records or filtered by name"""
        url = f"{self.base_url}/zones/{self.zone_id}/dns_records"
        params = {"name": name} if name else {}

        try:
            response = requests.get(url, headers=self.headers, params=params, timeout=10)
            if response.status_code == 200:
                return response.json()['result']
        except Exception as e:
            logger.error(f"Error getting DNS records: {e}")
        return []

    def create_dns_record(self, name: str, type: str, content: str,
                         ttl: int = 300, proxied: bool = True) -> Optional[Dict]:
        """Create new DNS record"""
        full_name = f"{name}.{self.domain}" if name else self.domain

        url = f"{self.base_url}/zones/{self.zone_id}/dns_records"
        data = {
            "type": type,
            "name": full_name,
            "content": content,
            "ttl": ttl,
            "proxied": proxied
        }

        try:
            response = requests.post(url, headers=self.headers, json=data, timeout=10)
            if response.status_code == 200:
                record = response.json()['result']
                logger.info(f"✓ Created DNS record: {full_name} -> {content}")
                return record
            else:
                logger.error(f"✗ Failed to create record: {response.text}")
        except Exception as e:
            logger.error(f"Error creating DNS record: {e}")
        return None

    def update_dns_record(self, record_id: str, content: str, proxied: bool = True) -> bool:
        """Update existing DNS record"""
        url = f"{self.base_url}/zones/{self.zone_id}/dns_records/{record_id}"
        data = {"content": content, "proxied": proxied}

        try:
            response = requests.patch(url, headers=self.headers, json=data, timeout=10)
            if response.status_code == 200:
                logger.info(f"✓ Updated DNS record {record_id} to {content}")
                return True
            else:
                logger.error(f"✗ Failed to update record: {response.text}")
        except Exception as e:
            logger.error(f"Error updating DNS record: {e}")
        return False

    def delete_dns_record(self, record_id: str) -> bool:
        """Delete DNS record"""
        url = f"{self.base_url}/zones/{self.zone_id}/dns_records/{record_id}"

        try:
            response = requests.delete(url, headers=self.headers, timeout=10)
            if response.status_code == 200:
                logger.info(f"✓ Deleted DNS record {record_id}")
                return True
        except Exception as e:
            logger.error(f"Error deleting DNS record: {e}")
        return False

    def enable_ddos_protection(self, record_id: str) -> bool:
        """Enable DDoS protection by proxying through Cloudflare"""
        return self.update_dns_record(record_id, proxied=True)

    def enable_firewall_rule(self, expression: str, action: str = "block",
                           description: str = "") -> bool:
        """Create firewall rule"""
        url = f"{self.base_url}/zones/{self.zone_id}/firewall/rules"
        data = {
            "filter": {
                "expression": expression,
                "paused": False
            },
            "action": action,
            "description": description or f"Auto-rule: {expression}"
        }

        try:
            response = requests.post(url, headers=self.headers, json=data, timeout=10)
            if response.status_code in [200, 201]:
                logger.info(f"✓ Created firewall rule: {expression}")
                return True
            else:
                logger.error(f"✗ Failed to create firewall rule: {response.text}")
        except Exception as e:
            logger.error(f"Error creating firewall rule: {e}")
        return False

    def get_zone_analytics(self, since: int = 3600) -> Dict:
        """Get zone analytics"""
        url = f"{self.base_url}/zones/{self.zone_id}/analytics/dashboard"
        params = {
            "since": int(time.time()) - since,
            "until": int(time.time())
        }

        try:
            response = requests.get(url, headers=self.headers, params=params, timeout=10)
            if response.status_code == 200:
                return response.json()['result']
        except Exception as e:
            logger.error(f"Error getting analytics: {e}")
        return {}

    def export_dns_records(self, output_file: str = "dns_backup.json") -> int:
        """Export all DNS records to file"""
        records = self.get_dns_records()
        try:
            with open(output_file, 'w') as f:
                json.dump(records, f, indent=2)
            logger.info(f"✓ Exported {len(records)} records to {output_file}")
            return len(records)
        except Exception as e:
            logger.error(f"Error exporting DNS records: {e}")
            return 0

    def import_dns_records(self, input_file: str) -> int:
        """Import DNS records from backup file"""
        try:
            with open(input_file, 'r') as f:
                records = json.load(f)

            imported = 0
            for record in records:
                name = record['name'].replace(f".{self.domain}", "")
                if self.create_dns_record(
                    name=name,
                    type=record['type'],
                    content=record['content'],
                    ttl=record.get('ttl', 300),
                    proxied=record.get('proxied', True)
                ):
                    imported += 1

            logger.info(f"✓ Imported {imported}/{len(records)} records")
            return imported
        except Exception as e:
            logger.error(f"Error importing DNS records: {e}")
            return 0


def main():
    """CLI interface for Cloudflare manager"""
    import sys

    if len(sys.argv) < 2:
        print("Usage: cloudflare_manager.py <command> [args]")
        print("Commands: validate, list, create, export, import")
        sys.exit(1)

    cf = CloudflareManager()
    command = sys.argv[1]

    if command == "validate":
        cf.validate_credentials()
    elif command == "list":
        records = cf.get_dns_records()
        for r in records:
            print(f"{r['name']:40} {r['type']:6} {r['content']:20} {'[PROXIED]' if r.get('proxied') else ''}")
    elif command == "export":
        filename = sys.argv[2] if len(sys.argv) > 2 else "dns_backup.json"
        cf.export_dns_records(filename)
    elif command == "import":
        if len(sys.argv) < 3:
            print("Usage: cloudflare_manager.py import <filename>")
            sys.exit(1)
        cf.import_dns_records(sys.argv[2])
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)


if __name__ == "__main__":
    main()
