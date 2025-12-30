#!/usr/bin/env python3
"""
Domain Manager - Service Registration and Nginx Automation
Part of the AI Empire deployment suite
"""

import os
import psycopg2
import subprocess
import logging
from typing import Optional, Dict, List
from datetime import datetime

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class DomainManager:
    """
    Complete domain and service management for automatic Nginx configuration,
    SSL certificate provisioning, and service health monitoring
    """

    def __init__(self):
        self.db_host = os.getenv('DB_HOST', 'localhost')
        self.db_port = os.getenv('DB_PORT', '5432')
        self.db_name = os.getenv('DB_NAME', 'ai_empire')
        self.db_user = os.getenv('DB_USER', 'postgres')
        self.db_password = os.getenv('DB_PASSWORD', 'changeme')
        self.domain = os.getenv('DOMAIN_NAME', 'example.com')
        self.nginx_conf_dir = os.getenv('NGINX_CONF_DIR', '/etc/nginx/sites-enabled')

        self.conn = None
        self._connect()
        self._ensure_schema()

    def _connect(self):
        """Connect to PostgreSQL database"""
        try:
            self.conn = psycopg2.connect(
                host=self.db_host,
                port=self.db_port,
                dbname=self.db_name,
                user=self.db_user,
                password=self.db_password
            )
            logger.info("✓ Connected to PostgreSQL database")
        except Exception as e:
            logger.error(f"✗ Database connection failed: {e}")
            self.conn = None

    def _ensure_schema(self):
        """Create database schema if it doesn't exist"""
        if not self.conn:
            return

        schema = """
        CREATE TABLE IF NOT EXISTS services (
            id SERIAL PRIMARY KEY,
            name VARCHAR(100) UNIQUE NOT NULL,
            subdomain VARCHAR(100) NOT NULL,
            port INTEGER NOT NULL,
            protocol VARCHAR(10) DEFAULT 'http',
            ssl_enabled BOOLEAN DEFAULT false,
            health_check_path VARCHAR(200) DEFAULT '/health',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS service_health (
            id SERIAL PRIMARY KEY,
            service_id INTEGER REFERENCES services(id) ON DELETE CASCADE,
            status VARCHAR(20) NOT NULL,
            response_time_ms INTEGER,
            checked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        CREATE INDEX IF NOT EXISTS idx_service_health_service_id ON service_health(service_id);
        CREATE INDEX IF NOT EXISTS idx_service_health_checked_at ON service_health(checked_at);
        """

        try:
            with self.conn.cursor() as cursor:
                cursor.execute(schema)
                self.conn.commit()
            logger.info("✓ Database schema initialized")
        except Exception as e:
            logger.error(f"✗ Schema creation failed: {e}")
            self.conn.rollback()

    def register_service(self, name: str, subdomain: str, port: int,
                        protocol: str = 'http', ssl_enabled: bool = True) -> bool:
        """Register a new service"""
        if not self.conn:
            logger.error("✗ No database connection")
            return False

        try:
            with self.conn.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO services (name, subdomain, port, protocol, ssl_enabled)
                    VALUES (%s, %s, %s, %s, %s)
                    ON CONFLICT (name) DO UPDATE SET
                        subdomain = EXCLUDED.subdomain,
                        port = EXCLUDED.port,
                        protocol = EXCLUDED.protocol,
                        ssl_enabled = EXCLUDED.ssl_enabled,
                        updated_at = CURRENT_TIMESTAMP
                    """,
                    (name, subdomain, port, protocol, ssl_enabled)
                )
                self.conn.commit()
            logger.info(f"✓ Registered service: {name} -> {subdomain}.{self.domain}:{port}")
            return True
        except Exception as e:
            logger.error(f"✗ Failed to register service: {e}")
            self.conn.rollback()
            return False

    def get_service(self, name: str) -> Optional[Dict]:
        """Get service configuration"""
        if not self.conn:
            return None

        try:
            with self.conn.cursor() as cursor:
                cursor.execute(
                    "SELECT * FROM services WHERE name = %s",
                    (name,)
                )
                row = cursor.fetchone()
                if row:
                    return {
                        'id': row[0],
                        'name': row[1],
                        'subdomain': row[2],
                        'port': row[3],
                        'protocol': row[4],
                        'ssl_enabled': row[5],
                        'health_check_path': row[6],
                        'created_at': row[7],
                        'updated_at': row[8]
                    }
        except Exception as e:
            logger.error(f"Error getting service: {e}")
        return None

    def list_services(self) -> List[Dict]:
        """List all registered services"""
        if not self.conn:
            return []

        try:
            with self.conn.cursor() as cursor:
                cursor.execute("SELECT * FROM services ORDER BY name")
                rows = cursor.fetchall()
                return [{
                    'id': row[0],
                    'name': row[1],
                    'subdomain': row[2],
                    'port': row[3],
                    'protocol': row[4],
                    'ssl_enabled': row[5],
                    'health_check_path': row[6],
                    'created_at': row[7],
                    'updated_at': row[8]
                } for row in rows]
        except Exception as e:
            logger.error(f"Error listing services: {e}")
            return []

    def delete_service(self, name: str) -> bool:
        """Delete a service"""
        if not self.conn:
            return False

        try:
            with self.conn.cursor() as cursor:
                cursor.execute("DELETE FROM services WHERE name = %s", (name,))
                self.conn.commit()
            logger.info(f"✓ Deleted service: {name}")
            return True
        except Exception as e:
            logger.error(f"✗ Failed to delete service: {e}")
            self.conn.rollback()
            return False

    def generate_nginx_config(self, service: Dict) -> str:
        """Generate Nginx configuration for a service"""
        full_domain = f"{service['subdomain']}.{self.domain}"

        if service['ssl_enabled']:
            config = f"""
server {{
    listen 80;
    server_name {full_domain};
    return 301 https://$server_name$request_uri;
}}

server {{
    listen 443 ssl http2;
    server_name {full_domain};

    ssl_certificate /etc/letsencrypt/live/{full_domain}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/{full_domain}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {{
        proxy_pass {service['protocol']}://localhost:{service['port']};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }}
}}
"""
        else:
            config = f"""
server {{
    listen 80;
    server_name {full_domain};

    location / {{
        proxy_pass {service['protocol']}://localhost:{service['port']};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }}
}}
"""
        return config

    def deploy_nginx_config(self, service_name: str) -> bool:
        """Deploy Nginx configuration for a service"""
        service = self.get_service(service_name)
        if not service:
            logger.error(f"✗ Service not found: {service_name}")
            return False

        config = self.generate_nginx_config(service)
        config_file = f"{self.nginx_conf_dir}/{service_name}.conf"

        try:
            with open(config_file, 'w') as f:
                f.write(config)
            logger.info(f"✓ Created Nginx config: {config_file}")

            # Test nginx configuration
            result = subprocess.run(
                ['sudo', 'nginx', '-t'],
                capture_output=True,
                text=True,
                timeout=10
            )

            if result.returncode == 0:
                # Reload nginx
                subprocess.run(
                    ['sudo', 'systemctl', 'reload', 'nginx'],
                    timeout=10
                )
                logger.info("✓ Nginx reloaded successfully")
                return True
            else:
                logger.error(f"✗ Nginx config test failed: {result.stderr}")
                os.remove(config_file)
                return False

        except Exception as e:
            logger.error(f"✗ Failed to deploy Nginx config: {e}")
            return False

    def provision_ssl_cert(self, service_name: str) -> bool:
        """Provision SSL certificate using certbot"""
        service = self.get_service(service_name)
        if not service:
            logger.error(f"✗ Service not found: {service_name}")
            return False

        full_domain = f"{service['subdomain']}.{self.domain}"

        try:
            result = subprocess.run(
                [
                    'sudo', 'certbot', 'certonly', '--nginx',
                    '-d', full_domain,
                    '--non-interactive',
                    '--agree-tos',
                    '--email', f'admin@{self.domain}'
                ],
                capture_output=True,
                text=True,
                timeout=120
            )

            if result.returncode == 0:
                logger.info(f"✓ SSL certificate provisioned for {full_domain}")
                # Update service to enable SSL
                with self.conn.cursor() as cursor:
                    cursor.execute(
                        "UPDATE services SET ssl_enabled = true WHERE name = %s",
                        (service_name,)
                    )
                    self.conn.commit()
                return True
            else:
                logger.error(f"✗ SSL provisioning failed: {result.stderr}")
                return False

        except Exception as e:
            logger.error(f"✗ SSL provisioning error: {e}")
            return False

    def check_service_health(self, service_name: str) -> Dict:
        """Check health of a service"""
        import requests
        import time

        service = self.get_service(service_name)
        if not service:
            return {'status': 'unknown', 'error': 'Service not found'}

        url = f"{service['protocol']}://localhost:{service['port']}{service['health_check_path']}"

        try:
            start_time = time.time()
            response = requests.get(url, timeout=5)
            response_time = int((time.time() - start_time) * 1000)

            status = 'healthy' if response.status_code == 200 else 'unhealthy'

            # Record health check
            with self.conn.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO service_health (service_id, status, response_time_ms)
                    VALUES (%s, %s, %s)
                    """,
                    (service['id'], status, response_time)
                )
                self.conn.commit()

            return {
                'status': status,
                'status_code': response.status_code,
                'response_time_ms': response_time
            }

        except Exception as e:
            # Record failed health check
            with self.conn.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO service_health (service_id, status, response_time_ms)
                    VALUES (%s, %s, NULL)
                    """,
                    (service['id'], 'down')
                )
                self.conn.commit()

            return {
                'status': 'down',
                'error': str(e)
            }

    def __del__(self):
        """Close database connection"""
        if self.conn:
            self.conn.close()


def main():
    """CLI interface for Domain manager"""
    import sys

    if len(sys.argv) < 2:
        print("Usage: domain_manager.py <command> [args]")
        print("Commands: register, list, deploy, ssl, health")
        sys.exit(1)

    dm = DomainManager()
    command = sys.argv[1]

    if command == "register":
        if len(sys.argv) < 5:
            print("Usage: domain_manager.py register <name> <subdomain> <port>")
            sys.exit(1)
        name, subdomain, port = sys.argv[2], sys.argv[3], int(sys.argv[4])
        dm.register_service(name, subdomain, port)

    elif command == "list":
        services = dm.list_services()
        for s in services:
            print(f"{s['name']:15} {s['subdomain']:20} :{s['port']:5} "
                  f"{'[SSL]' if s['ssl_enabled'] else '[HTTP]'}")

    elif command == "deploy":
        if len(sys.argv) < 3:
            print("Usage: domain_manager.py deploy <service_name>")
            sys.exit(1)
        dm.deploy_nginx_config(sys.argv[2])

    elif command == "ssl":
        if len(sys.argv) < 3:
            print("Usage: domain_manager.py ssl <service_name>")
            sys.exit(1)
        dm.provision_ssl_cert(sys.argv[2])

    elif command == "health":
        if len(sys.argv) < 3:
            print("Usage: domain_manager.py health <service_name>")
            sys.exit(1)
        result = dm.check_service_health(sys.argv[2])
        print(f"Status: {result['status']}")
        if 'response_time_ms' in result:
            print(f"Response Time: {result['response_time_ms']}ms")

    else:
        print(f"Unknown command: {command}")
        sys.exit(1)


if __name__ == "__main__":
    main()
