# Quick Start Guide

This guide will help you quickly set up a Debian system with BTRFS RAID1 and full disk encryption.

## Prerequisites

- Debian Live System (booted in UEFI mode)
- Two disks for RAID1
- Internet connection

## Installation Steps

1. Boot into Debian Live System in UEFI mode

2. Install git and clone this repository:
   ```bash
   apt update
   apt install -y git
   git clone https://github.com/username/debian-btrfs-raid
   cd debian-btrfs-raid
   ```

3. Make the script executable:
   ```bash
   chmod +x install.sh
   ```

4. Run the installation:
   ```bash
   sudo ./install.sh
   ```

5. Follow the prompts to configure:
   - System settings (hostname, username, timezone)
   - Disk selection and partitioning
   - Network configuration
   - Encryption passwords

## Post-Installation

After installation completes:
1. Remove the installation media
2. Reboot the system
3. Enter the LUKS encryption password when prompted
4. Log in with the user credentials you created

## Troubleshooting

Common issues and solutions:

1. System won't boot in UEFI mode
   - Enter BIOS/UEFI settings
   - Disable CSM/Legacy boot
   - Enable UEFI boot

2. No disks detected
   - Check disk connections
   - Ensure disks are not mounted
   - Run `lsblk` to verify disk visibility

3. Network issues
   - Check cable connection
   - Verify network interface name
   - Consider using static IP if DHCP fails

For more detailed information, check the [README.md](README.md) file.
