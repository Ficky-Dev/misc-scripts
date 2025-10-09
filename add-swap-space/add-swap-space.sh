#!/bin/bash
# Script to add swap space

# Function to log errors
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    error_exit "This script must be run as root. Use: sudo $0 [SWAP_SIZE_IN_GB]"
fi

# Check if swap file already exists
SWAPFILE=/swapfile
if [ -f "$SWAPFILE" ]; then
    echo "Swap file $SWAPFILE already exists."
    if swapon --show | grep -q "$SWAPFILE"; then
        echo "Swap is already active. Current swap status:"
        swapon --show
        free -h
        exit 0
    else
        read -p "Swap file exists but is not active. Do you want to remove and recreate it? (y/n): " RECREATE
        if [[ "$RECREATE" =~ ^[Yy]$ ]]; then
            echo "Removing existing swap file..."
            swapoff "$SWAPFILE" 2>/dev/null || true
            rm -f "$SWAPFILE" || error_exit "Failed to remove existing swap file"
        else
            echo "Exiting without changes."
            exit 0
        fi
    fi
fi

# Check if swap size is provided as argument
if [ -z "$1" ]; then
  # Ask user for swap size interactively
  read -p "Enter swap size in GB (e.g., 2): " SWAP_SIZE_GB
else
  SWAP_SIZE_GB="$1"
fi

# Validate input
if ! [[ "$SWAP_SIZE_GB" =~ ^[0-9]+$ ]]; then
  echo "Usage: $0 [SWAP_SIZE_IN_GB]"
  echo "Example: $0 2"
  error_exit "Please enter a valid number."
fi

# Check available disk space
AVAILABLE_SPACE=$(df --output=avail / | tail -1 | tr -d ' ')
REQUIRED_SPACE=$((SWAP_SIZE_GB * 1024 * 1024)) # Convert GB to KB

if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
    error_exit "Not enough disk space. Available: $(df -h / | tail -1 | awk '{print $4}'), Required: ${SWAP_SIZE_GB}G"
fi

echo "Creating swap file of ${SWAP_SIZE_GB}G at ${SWAPFILE}..."

# Create swap file with error handling
if ! fallocate -l ${SWAP_SIZE_GB}G $SWAPFILE; then
    echo "fallocate failed, trying dd command..."
    if ! dd if=/dev/zero of=$SWAPFILE bs=1G count=${SWAP_SIZE_GB} status=progress; then
        error_exit "Failed to create swap file using both fallocate and dd"
    fi
fi

# Set correct permissions
chmod 600 $SWAPFILE || error_exit "Failed to set permissions on swap file"

# Setup swap area
if ! mkswap $SWAPFILE; then
    error_exit "Failed to format swap file"
fi

# Enable swap
if ! swapon $SWAPFILE; then
    error_exit "Failed to enable swap"
fi

# Verify swap
echo "Swap status after setup:"
swapon --show

# Make swap permanent
if ! grep -q "$SWAPFILE" /etc/fstab; then
    echo "$SWAPFILE none swap sw 0 0" | tee -a /etc/fstab || error_exit "Failed to add swap to fstab"
fi

# Configure swappiness
SWAPPINESS_DEFAULT=60
echo "Configuring swappiness..."

# Check if user provided swappiness value
if [ -n "$2" ] && [[ "$2" =~ ^[0-9]+$ ]] && [ "$2" -ge 1 ] && [ "$2" -le 100 ]; then
    SWAPPINESS_VALUE="$2"
    echo "Using provided swappiness value: $SWAPPINESS_VALUE"
else
    echo "Using default swappiness value: $SWAPPINESS_DEFAULT"
    SWAPPINESS_VALUE="$SWAPPINESS_DEFAULT"
fi

# Set swappiness temporarily
if ! sysctl vm.swappiness=$SWAPPINESS_VALUE; then
    echo "Warning: Failed to set swappiness temporarily" >&2
else
    echo "Swappiness set to $SWAPPINESS_VALUE temporarily"
fi

# Make swappiness permanent
if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
    echo "vm.swappiness=$SWAPPINESS_VALUE" >> /etc/sysctl.conf || echo "Warning: Failed to make swappiness permanent in /etc/sysctl.conf" >&2
else
    # Update existing swappiness value
    sed -i "s/^vm.swappiness=.*/vm.swappiness=$SWAPPINESS_VALUE/" /etc/sysctl.conf || echo "Warning: Failed to update swappiness in /etc/sysctl.conf" >&2
fi

echo "Swap setup complete."
echo "Final system memory status:"
free -h
echo "Swap configuration details:"
echo "  Swap file: $SWAPFILE"
echo "  Swap size: ${SWAP_SIZE_GB}G"
echo "  Swappiness: $SWAPPINESS_VALUE"
echo ""
echo "Usage information:"
echo "  Lower swappiness (1-10): More aggressive RAM usage, less swapping"
echo "  Higher swappiness (60-100): More swapping to disk"
echo "  Recommended values: 10-60 for most systems"
