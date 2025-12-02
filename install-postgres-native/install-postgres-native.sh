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

# 2. DB Name
read -p "Enter Database Name [myappdb]: " DB_NAME
DB_NAME=${DB_NAME:-myappdb}

# 3. DB User
read -p "Enter Database Username [myuser]: " DB_USER
DB_USER=${DB_USER:-myuser}

# 4. DB Password (Hidden input)
while true; do
    echo -n "Enter Database Password: "
    read -s DB_PASS
    echo
    echo -n "Confirm Database Password: "
    read -s DB_PASS_CONFIRM
    echo
    [ "$DB_PASS" = "$DB_PASS_CONFIRM" ] && break
    echo -e "${RED}Passwords do not match! Please try again.${NC}"
done

echo -e "${GREEN}>>> Configuration Set:${NC}"
echo "Version: $DB_VERSION"
echo "Database: $DB_NAME"
echo "User: $DB_USER"
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

# Allow connection from anywhere
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/$DB_VERSION/main/postgresql.conf

# Allow password login (MD5/SCRAM) - Check if line exists to avoid duplicates
grep -q "0.0.0.0/0" /etc/postgresql/$DB_VERSION/main/pg_hba.conf || echo "host    all             all             0.0.0.0/0            scram-sha-256" >> /etc/postgresql/$DB_VERSION/main/pg_hba.conf

echo -e "${BLUE}>>> 5. Restarting Service...${NC}"
systemctl restart postgresql

echo -e "${BLUE}>>> 6. Setting up Database & Extension...${NC}"

# We use sudo -u postgres to execute psql commands
sudo -u postgres psql <<EOF
-- Create User if not exists
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DB_USER') THEN
    CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';
  ELSE
    ALTER USER $DB_USER WITH PASSWORD '$DB_PASS';
  END IF;
END
\$\$;

-- Create DB if not exists (Postgres doesn't support "CREATE DATABASE IF NOT EXISTS" easily inside a block, 
-- so we rely on the script continuing or handling the error gracefully. 
-- For a fresh install, this standard command is fine:
SELECT 'CREATE DATABASE $DB_NAME OWNER $DB_USER' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DB_NAME')\gexec

-- Switch to DB
\c $DB_NAME

-- Enable Vector Extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
ALTER DATABASE $DB_NAME OWNER TO $DB_USER;
GRANT ALL ON SCHEMA public TO $DB_USER;
EOF

echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}   INSTALLATION COMPLETE!                         ${NC}"
echo -e "${GREEN}==================================================${NC}"
echo -e "Database:  ${BLUE}$DB_NAME${NC}"
echo -e "User:      ${BLUE}$DB_USER${NC}"
echo -e "Port:      ${BLUE}5432${NC}"
echo -e "Extension: ${BLUE}pgvector (Enabled)${NC}"
echo ""
echo -e "${RED}IMPORTANT: Firewall Step${NC}"
echo "Run this command to allow external access:"
echo "ufw allow 5432/tcp"