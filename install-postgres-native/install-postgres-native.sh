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

# 3. DB Name
read -p "Enter Database Name [myappdb]: " DB_NAME
DB_NAME=${DB_NAME:-myappdb}

# 4. DB User
read -p "Enter Database Username [myuser]: " DB_USER
DB_USER=${DB_USER:-myuser}

# 5. Postgres Superuser Password (Optional - highly recommended)
echo -e "${BLUE}Setting up PostgreSQL superuser (postgres) password${NC}"
echo -e "${YELLOW}Note: This password allows full administrative access to PostgreSQL${NC}"
echo -e "${YELLOW}Leave blank to use default peer authentication${NC}"
echo ""
while true; do
    echo -n "Enter PostgreSQL superuser password (optional): "
    read -s POSTGRES_PASS
    echo

    if [ -z "$POSTGRES_PASS" ]; then
        echo -e "${YELLOW}Skipping superuser password configuration${NC}"
        break
    fi

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

# 6. DB Password (Hidden input)
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
echo "Port: $DB_PORT"
echo "Database: $DB_NAME"
echo "User: $DB_USER"
echo "Postgres Superuser Password: $([ -n "$POSTGRES_PASS" ] && echo "SET" || echo "NOT SET")"
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
sed -i "s/#port = 5432/port = $DB_PORT/" /etc/postgresql/$DB_VERSION/main/postgresql.conf

# Allow password login (MD5/SCRAM) - Check if line exists to avoid duplicates
grep -q "0.0.0.0/0" /etc/postgresql/$DB_VERSION/main/pg_hba.conf || echo "host    all             all             0.0.0.0/0            scram-sha-256" >> /etc/postgresql/$DB_VERSION/main/pg_hba.conf

echo -e "${BLUE}>>> 5. Restarting Service...${NC}"
systemctl restart postgresql

echo -e "${BLUE}>>> 6. Setting up Database & Extension...${NC}"

# Set postgres superuser password if provided
if [ -n "$POSTGRES_PASS" ]; then
    echo -e "${BLUE}>>> Setting postgres superuser password...${NC}"
    sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$POSTGRES_PASS';"
fi

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
echo -e "Database:              ${BLUE}$DB_NAME${NC}"
echo -e "User:                  ${BLUE}$DB_USER${NC}"
echo -e "Postgres Superuser:    ${BLUE}postgres${NC}"
echo -e "Port:                  ${BLUE}$DB_PORT${NC}"
echo -e "Extension:             ${BLUE}pgvector (Enabled)${NC}"
echo -e "Postgres Password:     ${BLUE}$([ -n "$POSTGRES_PASS" ] && echo "SET" || echo "NOT SET")${NC}"
echo ""
echo -e "${RED}IMPORTANT: Connection Information${NC}"
echo "For postgres superuser: ${YELLOW}sudo -u postgres psql -p $DB_PORT${NC}"
echo "For application user:  ${YELLOW}psql -h localhost -p $DB_PORT -U $DB_USER -d $DB_NAME${NC}"
echo ""
echo -e "${RED}IMPORTANT: Firewall Step${NC}"
echo "Run this command to allow external access:"
echo "ufw allow $DB_PORT/tcp"