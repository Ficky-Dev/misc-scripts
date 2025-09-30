#!/bin/bash

set -e

echo "[+] Updating package list..."
sudo apt update -y

echo "[+] Installing Ubuntu Desktop..."
sudo apt install -y ubuntu-desktop

echo "[+] Installing XRDP..."
sudo apt install -y xrdp

echo "[+] Enabling XRDP service to start on boot..."
sudo systemctl enable xrdp
sudo systemctl start xrdp

echo "[+] Configuring UFW firewall..."
# Install ufw if not already installed
if ! command -v ufw >/dev/null 2>&1; then
    sudo apt install -y ufw
fi

# Enable firewall if inactive (will prompt on first enable)
sudo ufw --force enable

# Always allow SSH and RDP
sudo ufw allow 22/tcp
sudo ufw allow 3389/tcp

echo "[+] Setting default boot to graphical (GUI)..."
sudo systemctl set-default graphical.target

echo "[+] Creating new user 'zoom'..."
# Add user with home directory and bash shell (skip if already exists)
if ! id "zoom" &>/dev/null; then
    sudo useradd -m -s /bin/bash zoom
fi

# Set password for the user
echo "zoom:zoom@Ficky.Dev" | sudo chpasswd

# Add 'zoom' user to sudo group
sudo usermod -aG sudo zoom

echo "[+] Setup complete. System will reboot now."
sudo reboot
