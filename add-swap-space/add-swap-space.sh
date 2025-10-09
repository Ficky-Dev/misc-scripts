#!/bin/bash
# Script to add swap space interactively

# Ask user for swap size
read -p "Enter swap size in GB (e.g., 2): " SWAP_SIZE_GB

# Validate input
if ! [[ "$SWAP_SIZE_GB" =~ ^[0-9]+$ ]]; then
  echo "Error: Please enter a valid number."
  exit 1
fi

SWAPFILE=/swapfile

echo "Creating swap file of ${SWAP_SIZE_GB}G at ${SWAPFILE}..."

# Create swap file
fallocate -l ${SWAP_SIZE_GB}G $SWAPFILE || dd if=/dev/zero of=$SWAPFILE bs=1G count=${SWAP_SIZE_GB}

# Set correct permissions
chmod 600 $SWAPFILE

# Setup swap area
mkswap $SWAPFILE

# Enable swap
swapon $SWAPFILE

# Verify swap
swapon --show

# Make swap permanent
if ! grep -q "$SWAPFILE" /etc/fstab; then
  echo "$SWAPFILE none swap sw 0 0" | tee -a /etc/fstab
fi

echo "Swap setup complete."
free -h
