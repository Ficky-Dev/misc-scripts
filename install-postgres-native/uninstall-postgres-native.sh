#!/bin/bash

# Stop script on first error
set -e

# --- COLORS FOR OUTPUT ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- ROOT CHECK ---
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root (use sudo)${NC}"
  exit 1
fi

echo -e "${BLUE}==================================================${NC}"
echo -e "${RED}   PostgreSQL + pgvector Uninstaller            ${NC}"
echo -e "${BLUE}==================================================${NC}"
echo -e "${RED}WARNING: This will completely remove PostgreSQL${NC}"
echo -e "${RED}         and ALL database data!                  ${NC}"
echo -e "${RED}         This action cannot be undone!          ${NC}"
echo ""

# --- DETECTION SECTION ---
echo -e "${BLUE}>>> Detecting PostgreSQL installations...${NC}"

# Detect all installed PostgreSQL versions
INSTALLED_VERSIONS=$(dpkg -l | grep -E "postgresql-[0-9]+" | awk '{print $2}' | sort -V || true)

if [ -z "$INSTALLED_VERSIONS" ]; then
    echo -e "${YELLOW}No PostgreSQL packages found installed.${NC}"
    echo -e "${YELLOW}However, checking for leftover data directories...${NC}"
else
    echo -e "${GREEN}Found PostgreSQL versions:${NC}"
    for version in $INSTALLED_VERSIONS; do
        echo "  - $version"
    done
    echo ""
fi

# Check for existing data directories
DATA_DIRS=""
for version_num in {9..17}; do
    if [ -d "/var/lib/postgresql/$version_num" ]; then
        if [ -n "$DATA_DIRS" ]; then
            DATA_DIRS="$DATA_DIRS, /var/lib/postgresql/$version_num"
        else
            DATA_DIRS="/var/lib/postgresql/$version_num"
        fi
    fi
done

if [ -n "$DATA_DIRS" ]; then
    echo -e "${YELLOW}Found data directories: $DATA_DIRS${NC}"
    echo -e "${YELLOW}These will be REMOVED if you continue!${NC}"
    echo ""
fi

# --- USER CONFIRMATION SECTION ---
echo -e "${RED}=== DANGER ZONE ===${NC}"
echo -e "${RED}This will permanently delete:${NC}"
echo -e "  - All PostgreSQL packages"
echo -e "  - All databases and data"
echo -e "  - All users and roles"
echo -e "  - Configuration files"
echo -e "  - Log files"
if [ -n "$DATA_DIRS" ]; then
    echo -e "  - Data directories: $DATA_DIRS"
fi
echo ""
echo -e "${RED}THIS ACTION CANNOT BE UNDONE!${NC}"
echo ""

# First confirmation - simple
read -p "Type 'UNINSTALL' to continue: " CONFIRM1
if [ "$CONFIRM1" != "UNINSTALL" ]; then
    echo -e "${YELLOW}Uninstallation cancelled.${NC}"
    exit 0
fi

# Second confirmation - with user's database name if we can detect it
echo ""
echo -e "${RED}FINAL WARNING: All PostgreSQL data will be lost forever!${NC}"
read -p "Type 'DELETE-ALL-DATA' to confirm permanent deletion: " CONFIRM2
if [ "$CONFIRM2" != "DELETE-ALL-DATA" ]; then
    echo -e "${YELLOW}Uninstallation cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${GREEN}>>> Starting uninstallation process...${NC}"

# --- BACKUP SECTION ---
echo -e "${BLUE}>>> Creating final backup of configurations...${NC}"

BACKUP_DIR="/tmp/postgres_uninstall_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup configuration files if they exist
for version_num in {9..17}; do
    CONFIG_DIR="/etc/postgresql/$version_num/main"
    if [ -d "$CONFIG_DIR" ]; then
        mkdir -p "$BACKUP_DIR/config_$version_num"
        cp -r "$CONFIG_DIR" "$BACKUP_DIR/config_$version_num/" 2>/dev/null || true
        echo -e "${GREEN}  Backed up configuration for version $version_num${NC}"
    fi
done

# Backup package list
dpkg -l | grep postgresql > "$BACKUP_DIR/installed_packages.txt" 2>/dev/null || true

echo -e "${GREEN}Configuration backup created at: $BACKUP_DIR${NC}"
echo ""

# --- STOP SERVICES ---
echo -e "${BLUE}>>> 1. Stopping PostgreSQL services...${NC}"

# Stop all PostgreSQL services
systemctl stop postgresql 2>/dev/null || true
systemctl stop postgresql@* 2>/dev/null || true

# Kill any remaining PostgreSQL processes
pkill -f postgres || true
sleep 2

# Disable services
systemctl disable postgresql 2>/dev/null || true
systemctl disable postgresql@* 2>/dev/null || true

echo -e "${GREEN}✓ PostgreSQL services stopped${NC}"

# --- REMOVE PACKAGES ---
echo -e "${BLUE}>>> 2. Removing PostgreSQL packages...${NC}"

# List of all possible PostgreSQL packages to remove
POSTGRES_PACKAGES="
postgresql
postgresql-common
postgresql-client
postgresql-client-common
postgresql-contrib
postgresql-doc
postgresql-plperl
postgresql-plpython3
postgresql-pltcl
postgresql-server-dev-all
pgdg-keyring
"

# Add version-specific packages
for version_num in {9..17}; do
    POSTGRES_PACKAGES="$POSTGRES_PACKAGES
postgresql-$version_num
postgresql-client-$version_num
postgresql-contrib-$version_num
postgresql-plperl-$version_num
postgresql-plpython3-$version_num
postgresql-pltcl-$version_num
postgresql-server-dev-$version_num
postgresql-$version_num-pgvector
postgresql-$version_num-pgvector-doc
postgresql-$version_num-pgvector-debuginfo
"
done

# Remove packages
for package in $POSTGRES_PACKAGES; do
    if dpkg -l | grep -q "^ii.*$package "; then
        echo -e "${YELLOW}  Removing: $package${NC}"
        apt-get remove --purge -y $package 2>/dev/null || true
    fi
done

# Auto-remove dependencies
apt-get autoremove -y
apt-get autoclean

echo -e "${GREEN}✓ PostgreSQL packages removed${NC}"

# --- REMOVE DATA AND CONFIGURATION ---
echo -e "${BLUE}>>> 3. Removing PostgreSQL data and configuration...${NC}"

# Ask user about configuration preservation
PRESERVE_CONFIG=false
read -p "Preserve PostgreSQL configuration directories? (y/N): " PRESERVE_CHOICE
if [[ "$PRESERVE_CHOICE" =~ ^[Yy]$ ]]; then
    PRESERVE_CONFIG=true
fi

# Remove data directories
if [ -n "$DATA_DIRS" ]; then
    for dir in $DATA_DIRS; do
        if [ -d "$dir" ]; then
            echo -e "${YELLOW}  Removing data directory: $dir${NC}"
            rm -rf "$dir"
        fi
    done
fi

# Remove main PostgreSQL directories if they exist
DIRECTORIES_TO_REMOVE="
/var/lib/postgresql
/etc/postgresql
/var/log/postgresql
/usr/lib/postgresql
/usr/include/postgresql
/usr/share/postgresql
/var/run/postgresql
/run/postgresql
"

for dir in $DIRECTORIES_TO_REMOVE; do
    if [ -d "$dir" ]; then
        if [ "$PRESERVE_CONFIG" = "true" ] && [ "$dir" = "/etc/postgresql" ]; then
            echo -e "${YELLOW}  Preserving configuration directory: $dir${NC}"
        else
            echo -e "${YELLOW}  Removing directory: $dir${NC}"
            rm -rf "$dir"
        fi
    fi
done

# Remove PostgreSQL user and group (only if no PostgreSQL processes remain)
if ! pgrep -u postgres >/dev/null 2>&1; then
    echo -e "${YELLOW}  Removing postgres user...${NC}"
    userdel -r postgres 2>/dev/null || true
    groupdel postgres 2>/dev/null || true
else
    echo -e "${YELLOW}  Postgres user still has processes, skipping user removal${NC}"
fi

# Remove logrotate configuration
if [ -f "/etc/logrotate.d/postgresql-common" ]; then
    echo -e "${YELLOW}  Removing logrotate configuration...${NC}"
    rm -f /etc/logrotate.d/postgresql-common
fi

# Remove systemd service files
echo -e "${YELLOW}  Cleaning up systemd files...${NC}"
systemctl daemon-reload
systemctl reset-failed 2>/dev/null || true

echo -e "${GREEN}✓ Data and configuration files removed${NC}"

# --- CLEANUP SYSTEM ---
echo -e "${BLUE}>>> 4. Final system cleanup...${NC}"

# Remove any remaining PostgreSQL-related files
find /tmp -name "s.PGSQL.*" -type s -delete 2>/dev/null || true
find /var/tmp -name "s.PGSQL.*" -type s -delete 2>/dev/null || true

# Clean up any remaining apt sources
if [ -f "/etc/apt/sources.list.d/pgdg.list" ]; then
    echo -e "${YELLOW}  Removing PostgreSQL APT source...${NC}"
    rm -f /etc/apt/sources.list.d/pgdg.list
fi

# Clean GPG keys
if [ -f "/etc/apt/trusted.gpg.d/postgresql.gpg" ]; then
    echo -e "${YELLOW}  Removing PostgreSQL GPG keys...${NC}"
    rm -f /etc/apt/trusted.gpg.d/postgresql.gpg
fi

# Update package lists
apt-get update -qq

echo -e "${GREEN}✓ System cleanup completed${NC}"

# --- COMPLETION ---
echo ""
echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}   UNINSTALLATION COMPLETE!                     ${NC}"
echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}✓ PostgreSQL has been completely removed${NC}"
echo -e "${GREEN}✓ All data and packages have been deleted${NC}"

if [ "$PRESERVE_CONFIG" = "true" ]; then
    echo -e "${GREEN}✓ Configuration preserved in /etc/postgresql${NC}"
fi

echo ""
echo -e "${BLUE}Backup location: $BACKUP_DIR${NC}"
echo -e "${YELLOW}Note: Backup will be automatically removed on system reboot${NC}"
echo ""

# Verify complete removal
echo -e "${BLUE}>>> Verifying complete removal...${NC}"

REMAINING=$(dpkg -l | grep postgresql 2>/dev/null || true)
if [ -n "$REMAINING" ]; then
    echo -e "${YELLOW}Warning: Some PostgreSQL packages may remain:${NC}"
    echo "$REMAINING"
else
    echo -e "${GREEN}✓ No PostgreSQL packages found${NC}"
fi

REMAINING_DIRS=""
for dir in /var/lib/postgresql /etc/postgresql /usr/lib/postgresql; do
    if [ -d "$dir" ]; then
        REMAINING_DIRS="$REMAINING_DIRS $dir"
    fi
done

if [ -n "$REMAINING_DIRS" ]; then
    echo -e "${YELLOW}Warning: Some directories may remain:$REMAINING_DIRS${NC}"
else
    echo -e "${GREEN}✓ No PostgreSQL directories found${NC}"
fi

echo ""
echo -e "${GREEN}PostgreSQL has been successfully uninstalled.${NC}"