#!/bin/bash

# Stop script on first error
set -e

# --- COLORS FOR OUTPUT ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- ROOT CHECK ---
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root (use sudo)${NC}"
  exit
fi

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}   PostgreSQL + pgvector Interactive Installer    ${NC}"
echo -e "${BLUE}==================================================${NC}"

# --- USER INPUT SECTION ---

# 1. DB Version
read -p "Enter PostgreSQL Version [16]: " DB_VERSION
DB_VERSION=${DB_VERSION:-16}

# 2. Port Number
read -p "Enter PostgreSQL Port [5432]: " DB_PORT
DB_PORT=${DB_PORT:-5432}

# 3. Postgres Superuser Password (Required)
echo -e "${BLUE}Setting up PostgreSQL superuser (postgres) password${NC}"
echo -e "${YELLOW}Note: This password allows full administrative access to PostgreSQL${NC}"
echo ""

while true; do
    echo -n "Enter PostgreSQL superuser password: "
    read -s POSTGRES_PASS
    echo

    if [ ${#POSTGRES_PASS} -lt 8 ]; then
        echo -e "${RED}Superuser password must be at least 8 characters${NC}"
        continue
    fi

    echo -n "Confirm PostgreSQL superuser password: "
    read -s POSTGRES_PASS_CONFIRM
    echo
    [ "$POSTGRES_PASS" = "$POSTGRES_PASS_CONFIRM" ] && break
    echo -e "${RED}Passwords do not match! Please try again.${NC}"
done

echo -e "${GREEN}>>> Configuration Set:${NC}"
echo "Version: $DB_VERSION"
echo "Port: $DB_PORT"
echo "Postgres Superuser Password: SET"
echo "--------------------------------------------------"

# --- INSTALLATION SECTION ---

echo -e "${BLUE}>>> 1. Updating System...${NC}"
apt-get update -qq

echo -e "${BLUE}>>> 2. Adding Official PostgreSQL Repo...${NC}"
apt-get install -y dirmngr ca-certificates software-properties-common gnupg gnupg2 curl lsb-release
sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg --yes

echo -e "${BLUE}>>> 3. Installing PostgreSQL $DB_VERSION and pgvector...${NC}"
apt-get update -qq
# Install Postgres and the vector extension specifically for this version
apt-get install -y postgresql-$DB_VERSION postgresql-$DB_VERSION-pgvector

echo -e "${BLUE}>>> 4. Configuring Access...${NC}"
# Backup config file first
cp /etc/postgresql/$DB_VERSION/main/postgresql.conf /etc/postgresql/$DB_VERSION/main/postgresql.conf.bak

# Allow connection from anywhere and set custom port
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/$DB_VERSION/main/postgresql.conf

# Set port configuration - handle both commented and uncommented cases
sed -i "s/^#port = 5432/port = $DB_PORT/" /etc/postgresql/$DB_VERSION/main/postgresql.conf
sed -i "s/^port = 5432/port = $DB_PORT/" /etc/postgresql/$DB_VERSION/main/postgresql.conf

# If no port line exists, add it
if ! grep -q "^port = " /etc/postgresql/$DB_VERSION/main/postgresql.conf; then
    echo "port = $DB_PORT" >> /etc/postgresql/$DB_VERSION/main/postgresql.conf
fi

# Allow password login (MD5/SCRAM) - Check if line exists to avoid duplicates
grep -q "0.0.0.0/0" /etc/postgresql/$DB_VERSION/main/pg_hba.conf || echo "host    all             all             0.0.0.0/0            scram-sha-256" >> /etc/postgresql/$DB_VERSION/main/pg_hba.conf

echo -e "${BLUE}>>> 5. Restarting Service...${NC}"
systemctl restart postgresql

echo -e "${BLUE}>>> 6. Setting up Database & Extension...${NC}"

# Setup postgres superuser password and enable pgvector extension
echo -e "${BLUE}>>> Setting up postgres superuser and pgvector extension...${NC}"
sudo -u postgres psql <<EOF
-- Set postgres superuser password
ALTER USER postgres PASSWORD '$POSTGRES_PASS';

-- Enable pgvector extension in default postgres database
CREATE EXTENSION IF NOT EXISTS vector;
EOF

echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}   INSTALLATION COMPLETE!                         ${NC}"
echo -e "${GREEN}==================================================${NC}"
echo -e "Postgres Superuser:    ${BLUE}postgres${NC}"
echo -e "Port:                  ${BLUE}$DB_PORT${NC}"
echo -e "Extension:             ${BLUE}pgvector (Enabled)${NC}"
echo -e "Postgres Password:     ${BLUE}SET${NC}"
echo ""
echo -e "${RED}IMPORTANT: Connection Information${NC}"
echo "For postgres superuser: ${YELLOW}sudo -u postgres psql -p $DB_PORT${NC}"
echo ""
echo -e "${RED}IMPORTANT: Firewall Step${NC}"
echo "Run this command to allow external access:"
echo "ufw allow $DB_PORT/tcp"