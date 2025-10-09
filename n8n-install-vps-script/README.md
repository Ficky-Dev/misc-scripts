# n8n Docker Installation Script

This script automates the installation of n8n with Docker, PostgreSQL database, Nginx reverse proxy, and SSL certificates (via Let's Encrypt) on your VPS or server.

## Features

- Automated n8n installation with Docker
- PostgreSQL database with health checks
- Nginx reverse proxy configuration
- Automatic SSL certificate generation and renewal
- WebSocket support for real-time n8n features
- Basic authentication setup

## Prerequisites

- Ubuntu/Debian-based Linux system
- Root or sudo access
- Domain name pointed to your server's IP address (optional but recommended for SSL)

## Usage

**Quick one-liner:**
```bash
curl -fsSL https://raw.githubusercontent.com/Ficky-Dev/misc-scripts/main/n8n-install-vps-script/install-n8n.sh | bash
```

Or download and run manually:

1. Make the script executable:
   ```bash
   chmod +x install-n8n.sh
   ```

2. Run the installation script:
   ```bash
   ./install-n8n.sh
   ```

3. Follow the prompts to configure:
   - n8n username (default: admin)
   - n8n password
   - Domain name (e.g., n8n.example.com)
   - Email for SSL certificate (optional)

## What Gets Installed

- Docker and Docker Compose
- PostgreSQL database container
- n8n container
- Nginx reverse proxy container
- Certbot for SSL certificates
- Automatic SSL renewal via cron job

## After Installation

- Access n8n at: `https://your-domain`
- Check logs: `cd ~/n8n-docker && docker compose logs -f`
- Stop services: `cd ~/n8n-docker && docker compose down`
- SSL certificates are stored in: `~/n8n-docker/certbot/conf/live/your-domain/`

## SSL Auto-Renewal

The script automatically sets up SSL certificate renewal via cron job that runs daily at 3 AM.

## Troubleshooting

If you encounter issues, check the container logs:
```bash
cd ~/n8n-docker
docker compose logs -f [service-name]
```

Available services: `db`, `n8n`, `nginx`, `certbot`