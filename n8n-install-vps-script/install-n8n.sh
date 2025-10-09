#!/bin/bash

# ============================================
# Automated n8n + Docker + Nginx + SSL Installer
# (with DB healthcheck + startup dependency fix)
# ============================================

set -e

echo "====================================="
echo "       n8n Docker Installation        "
echo "====================================="

# --- Get user inputs ---
read -p "Enter n8n username (default: admin): " N8N_USER
N8N_USER=${N8N_USER:-admin}

read -s -p "Enter n8n password: " N8N_PASSWORD
echo ""
read -s -p "Confirm password: " CONFIRM_PASSWORD
echo ""

if [ "$N8N_PASSWORD" != "$CONFIRM_PASSWORD" ]; then
  echo "Error: Passwords do not match."
  exit 1
fi

read -p "Enter your domain (e.g. n8n.example.com): " DOMAIN
DOMAIN=${DOMAIN:-n8n.localhost}

read -p "Enter your email for SSL certificate (optional): " EMAIL

# --- Create working directory ---
mkdir -p ~/n8n-docker
cd ~/n8n-docker

# --- Create .env file for docker-compose ---
cat <<EOF > .env
N8N_USER=${N8N_USER}
N8N_PASSWORD=${N8N_PASSWORD}
DOMAIN=${DOMAIN}
EOF

# --- Generate docker-compose.yml ---
cat <<'EOF' > docker-compose.yml
services:
  db:
    image: postgres:17.5
    restart: unless-stopped
    environment:
      - POSTGRES_USER=n8n
      - POSTGRES_PASSWORD=n8npass
      - POSTGRES_DB=n8n
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - n8n_net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U n8n"]
      interval: 5s
      timeout: 3s
      retries: 10

  n8n:
    image: n8nio/n8n
    container_name: n8n
    restart: unless-stopped
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=db
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=n8npass
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=${N8N_USER}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_PASSWORD}
      - N8N_HOST=${DOMAIN}
      - WEBHOOK_URL=https://${DOMAIN}
      - N8N_PUSH_BACKEND=websocket
      - N8N_EXPRESS_TRUST_PROXY=true
      - N8N_RUNNERS_ENABLED=true
      - N8N_BLOCK_ENV_ACCESS_IN_NODE=false
      - N8N_GIT_NODE_DISABLE_BARE_REPOS=true
      - N8N_TRUSTED_PROXIES="0.0.0.0/0"

    depends_on:
      db:
        condition: service_healthy
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - n8n_net

  nginx:
    image: nginx:latest
    container_name: nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./certbot/www:/var/www/certbot
      - ./certbot/conf:/etc/letsencrypt
    depends_on:
      - n8n
    networks:
      - n8n_net

  certbot:
    image: certbot/certbot
    container_name: certbot
    volumes:
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    networks:
      - n8n_net

networks:
  n8n_net:

volumes:
  postgres_data:
  n8n_data:
EOF

# --- Create directories ---
mkdir -p nginx/conf.d certbot/www certbot/conf

# --- Temporary nginx config for HTTP challenge ---
cat <<EOF > nginx/conf.d/${DOMAIN}.conf
server {
    listen 80;
    server_name ${DOMAIN};

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}
EOF

# --- Check Docker installation ---
if ! command -v docker &> /dev/null; then
  echo "Docker not found. Installing..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker $USER
  echo "Docker installed. Log out and back in to activate permissions."
fi

# --- Check Docker Compose installation ---
if ! docker compose version &> /dev/null; then
  echo "Docker Compose not found. Installing..."
  sudo apt update
  sudo apt install -y docker-compose-plugin || sudo apt install -y docker-compose
fi

# --- Ensure firewall allows ports 80 and 443 ---
if command -v ufw &> /dev/null; then
  sudo ufw allow 80 || true
  sudo ufw allow 443 || true
fi

# --- Start temporary Nginx for SSL verification ---
echo "Starting temporary Nginx for SSL verification..."
docker compose up -d nginx

# --- Obtain Let's Encrypt SSL certificate ---
echo "Requesting SSL certificate from Let's Encrypt..."
if [ -n "$EMAIL" ]; then
  docker compose run --rm certbot certonly \
    --webroot -w /var/www/certbot \
    -d ${DOMAIN} \
    --agree-tos \
    --email ${EMAIL} \
    --non-interactive
else
  docker compose run --rm certbot certonly \
    --webroot -w /var/www/certbot \
    -d ${DOMAIN} \
    --agree-tos \
    --register-unsafely-without-email \
    --non-interactive
fi

# --- Create HTTPS nginx config ---
cat <<EOF > nginx/conf.d/${DOMAIN}.conf
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name ${DOMAIN};

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://n8n:5678;
        proxy_http_version 1.1;
        proxy_cache off;
        proxy_buffering off;
        chunked_transfer_encoding off;

        # WebSocket support
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Required headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;

    }
}
EOF

# --- Restart all services with HTTPS enabled ---
echo "Restarting containers with HTTPS enabled..."
docker compose down
docker compose up -d

# --- Add SSL renewal to cron ---
echo "Setting up automatic SSL renewal..."
(crontab -l 2>/dev/null; echo "0 3 * * * cd ~/n8n-docker && docker compose run --rm certbot renew --quiet && docker compose exec nginx nginx -s reload") | crontab -

# --- Summary ---
echo ""
echo "====================================="
echo " n8n installation complete! "
echo "-------------------------------------"
echo " URL: https://${DOMAIN}"
echo " Username: ${N8N_USER}"
echo " Password: (hidden)"
echo "-------------------------------------"
echo " To check logs: docker compose logs -f"
echo " To stop: docker compose down"
echo " SSL auto-renewal: enabled (daily at 3 AM)"
echo " Certificates: ~/n8n-docker/certbot/conf/live/${DOMAIN}/"
echo "====================================="
