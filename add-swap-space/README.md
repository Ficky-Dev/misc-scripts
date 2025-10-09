# Add Swap Space Script

This script allows you to interactively add swap space to your Linux system.

## Usage

### One-liner command to run the script:
```bash
curl -s https://raw.githubusercontent.com/your-repo/misc-scripts/main/add-swap-space/add-swap-space.sh | sudo bash
```

Or if you have the file locally:
```bash
sudo bash add-swap-space.sh
```

## What the script does:

1. Prompts you to enter the desired swap size in GB
2. Creates a swap file at `/swapfile` with the specified size
3. Sets appropriate permissions (600)
4. Formats the file as swap
5. Enables the swap immediately
6. Adds the swap file to `/etc/fstab` to make it permanent
7. Displays the final memory status

## Requirements:

- Root privileges (run with sudo)
- Linux system
- Available disk space for the swap file

## Example:
```bash
sudo bash add-swap-space.sh
# Enter swap size in GB (e.g., 2): 4
```