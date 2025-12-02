# PostgreSQL + pgvector Interactive Installer

An automated installation script for PostgreSQL with the pgvector extension, designed for Ubuntu/Debian systems. This script sets up a complete PostgreSQL database server with vector support for AI/ML applications.

## 🚀 Features

- **Interactive Configuration**: Guided setup with sensible defaults
- **Multiple PostgreSQL Versions**: Support for any available PostgreSQL version (default: 16)
- **pgvector Extension**: Automatic installation and configuration for vector operations
- **Remote Access**: Pre-configured for remote connections (requires firewall setup)
- **Security**: Uses SCRAM-SHA-256 authentication
- **Backup Safety**: Automatic backup of configuration files before modifications

## 📋 System Requirements

- Ubuntu/Debian-based Linux distribution
- Root/sudo privileges
- Internet connection for package downloads
- Minimum 2GB RAM (recommended for production)

## 🔧 Installation

### Quick Start

```bash
# Clone or download the script
wget https://raw.githubusercontent.com/Ficky-Dev/misc-scripts/main/install-postgres-native/install-postgres-native.sh

# Make executable
chmod +x install-postgres-native.sh

# Run with sudo
sudo ./install-postgres-native.sh
```

### Interactive Configuration

The script will prompt for the following configuration:

| Setting | Default | Description |
|---------|---------|-------------|
| PostgreSQL Version | `16` | Major version to install |
| Database Name | `myappdb` | Name of the primary database |
| Database User | `myuser` | Username for database access |
| Database Password | *Required* | Secure password for the database user |

## 🛡️ Security Configuration

### Firewall Setup (Required)

After installation, configure your firewall to allow PostgreSQL connections:

```bash
# Allow PostgreSQL port (5432)
sudo ufw allow 5432/tcp

# Or restrict to specific IP ranges
sudo ufw allow from 192.168.1.0/24 to any port 5432
```

### Authentication

The script configures PostgreSQL with:
- **SCRAM-SHA-256** authentication for secure password storage
- Remote access enabled (configurable via `pg_hba.conf`)
- Connection listening on all interfaces (`*`)

## 📊 Connection Information

After successful installation, you'll receive:

- **Database**: `[configured_name]`
- **User**: `[configured_user]`
- **Port**: `5432`
- **Extension**: `pgvector` (enabled)

## 🔗 Connecting to PostgreSQL

### Command Line
```bash
psql -h localhost -p 5432 -U [username] -d [database_name]
```

### Python (psycopg2)
```python
import psycopg2

conn = psycopg2.connect(
    host="localhost",
    port="5432",
    database="[database_name]",
    user="[username]",
    password="[your_password]"
)
```

### Node.js (pg)
```javascript
const { Client } = require('pg');

const client = new Client({
    host: 'localhost',
    port: 5432,
    database: '[database_name]',
    user: '[username]',
    password: '[your_password]'
});

await client.connect();
```

## 🔧 pgvector Usage

The pgvector extension enables vector similarity search for AI/ML applications:

### SQL Examples
```sql
-- Create a table with vector support
CREATE TABLE items (
    id SERIAL PRIMARY KEY,
    name TEXT,
    embedding VECTOR(1536)  -- OpenAI embedding dimension
);

-- Insert vector data
INSERT INTO items (name, embedding) VALUES
    ('Item 1', '[0.1, 0.2, 0.3, ...]'),
    ('Item 2', '[0.4, 0.5, 0.6, ...]');

-- Perform similarity search
SELECT name, embedding <=> '[0.1, 0.2, 0.3]' as distance
FROM items
ORDER BY distance
LIMIT 5;
```

## 🗂️ File Locations

The script installs PostgreSQL to standard locations:

- **Config Files**: `/etc/postgresql/[version]/main/`
- **Data Directory**: `/var/lib/postgresql/[version]/main/`
- **Log Files**: `/var/log/postgresql/`
- **Binaries**: `/usr/lib/postgresql/[version]/bin/`

### Important Files
- `postgresql.conf` - Main configuration (backup: `.bak`)
- `pg_hba.conf` - Host-based authentication
- `pg_ident.conf` - User name mapping

## 🔧 Post-Installation Management

### Service Management
```bash
# Start PostgreSQL
sudo systemctl start postgresql

# Stop PostgreSQL
sudo systemctl stop postgresql

# Restart PostgreSQL
sudo systemctl restart postgresql

# Check status
sudo systemctl status postgresql

# Enable on boot
sudo systemctl enable postgresql
```

### User Management
```bash
# Switch to postgres user
sudo -u postgres -i

# Access psql as postgres
sudo -u postgres psql
```

### Database Management
```sql
-- List databases
\l

-- Connect to database
\c [database_name]

-- List users
\du

-- Show tables
\dt
```

## 🔍 Troubleshooting

### Common Issues

1. **Connection Refused**
   ```bash
   # Check if PostgreSQL is running
   sudo systemctl status postgresql

   # Check if port is listening
   sudo netstat -tlnp | grep 5432
   ```

2. **Authentication Failed**
   - Verify password in pg_hba.conf
   - Check user exists: `\du` in psql
   - Restart PostgreSQL after config changes

3. **Firewall Issues**
   ```bash
   # Check firewall status
   sudo ufw status

   # Add PostgreSQL port
   sudo ufw allow 5432/tcp
   ```

4. **Permission Issues**
   - Ensure running with sudo
   - Check file permissions in `/var/lib/postgresql/`

### Logs
```bash
# View PostgreSQL logs
sudo tail -f /var/log/postgresql/postgresql-[version]-main.log

# System logs
sudo journalctl -u postgresql
```

## 📝 Advanced Configuration

### Performance Tuning

Edit `/etc/postgresql/[version]/main/postgresql.conf`:

```ini
# Memory settings
shared_buffers = 256MB
effective_cache_size = 1GB

# Connection settings
max_connections = 100

# Query planning
random_page_cost = 1.1  # For SSD storage
```

### Security Hardening

1. **Restrict Connections in pg_hba.conf**:
   ```
   # Local connections only
   local   all             all                                     scram-sha-256
   host    all             all             127.0.0.1/32            scram-sha-256

   # Specific network (replace with your IP range)
   host    all             all             10.0.0.0/8              scram-sha-256
   ```

2. **SSL Configuration**:
   ```ini
   ssl = on
   ssl_cert_file = '/etc/ssl/certs/ssl-cert-snakeoil.pem'
   ssl_key_file = '/etc/ssl/private/ssl-cert-snakeoil.key'
   ```

## 🚨 Important Security Notes

- **Production Use**: Modify `pg_hba.conf` to restrict access to specific IP ranges
- **Default Configuration**: Script allows connections from any IP (0.0.0.0/0)
- **Firewall Required**: Always configure firewall rules after installation
- **Password Security**: Use strong, unique passwords
- **Regular Updates**: Keep PostgreSQL updated with security patches

## 📚 Additional Resources

- [PostgreSQL Official Documentation](https://www.postgresql.org/docs/)
- [pgvector GitHub Repository](https://github.com/pgvector/pgvector)
- [PostgreSQL Security Best Practices](https://www.postgresql.org/docs/current/security.html)

## 🗑️ Uninstallation

### Automated Uninstaller

A comprehensive uninstallation script is provided to completely remove PostgreSQL and all data:

```bash
# Download and run the uninstaller
wget https://raw.githubusercontent.com/Ficky-Dev/misc-scripts/main/install-postgres-native/uninstall-postgres-native.sh
chmod +x uninstall-postgres-native.sh
sudo ./uninstall-postgres-native.sh
```

⚠️ **DANGER**: This will permanently delete:
- All PostgreSQL packages and dependencies
- All databases, tables, and data
- All users and roles
- Configuration files (unless preserved)
- Log files and data directories
- PostgreSQL user account

### Safety Features

The uninstaller includes multiple safety layers:

1. **Double Confirmation Required**:
   - First: Type `UNINSTALL` to proceed
   - Second: Type `DELETE-ALL-DATA` for final confirmation

2. **Automatic Backup Creation**:
   - Configuration files backed up to `/tmp/postgres_uninstall_backup_*`
   - Package list saved for reference
   - Backup location displayed after completion

3. **Configuration Preservation Option**:
   - Choose to preserve `/etc/postgresql` directory
   - Useful for reinstallation with same settings

4. **Comprehensive Detection**:
   - Detects all PostgreSQL versions (9-17)
   - Finds all data directories
   - Lists all packages to be removed

### Manual Uninstallation

If you prefer manual removal:

```bash
# Stop services
sudo systemctl stop postgresql
sudo systemctl disable postgresql

# Remove packages (adjust version as needed)
sudo apt-get remove --purge postgresql* pgdg-keyring
sudo apt-get autoremove
sudo apt-get autoclean

# Remove data directories (CAUTION: deletes all data)
sudo rm -rf /var/lib/postgresql
sudo rm -rf /etc/postgresql
sudo rm -rf /var/log/postgresql

# Remove PostgreSQL user
sudo userdel -r postgres
```

### What Gets Removed

**Packages Removed**:
- PostgreSQL server and client packages
- PostgreSQL contrib modules
- Development headers and libraries
- pgvector extension packages
- Repository configuration

**Directories Removed**:
- `/var/lib/postgresql/` - All database data
- `/etc/postgresql/` - Configuration files (unless preserved)
- `/var/log/postgresql/` - Log files
- `/usr/lib/postgresql/` - Binary files
- `/usr/include/postgresql/` - Development headers

**Services Cleaned**:
- PostgreSQL service stopped and disabled
- Systemd service files cleaned
- Logrotate configurations removed

### Backup Recovery

After uninstallation, you can recover configurations from the backup:

```bash
# List available backups
ls -la /tmp/postgres_uninstall_backup_*

# Restore configuration (adjust paths as needed)
sudo cp -r /tmp/postgres_uninstall_backup_YYYYMMDD_HHMMSS/config_16/main/* /etc/postgresql/16/main/
sudo chown -R postgres:postgres /etc/postgresql/
```

## 🐛 Reporting Issues

If you encounter issues with this installer script:

1. Check the troubleshooting section above
2. Review system logs for error messages
3. Verify system requirements are met
4. Ensure proper permissions and firewall configuration

## 📄 License

This script is provided as-is for educational and development purposes. Always review and test installation scripts before use in production environments.

---

**⚠️ Warning**: This script modifies system files and installs services with root privileges. Review the script carefully and ensure you understand the changes being made to your system.