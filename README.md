# Debian BTRFS RAID1 Installation Script

This script automates the installation of Debian with BTRFS RAID1 and LUKS encryption. It provides a modular approach to setting up a fully encrypted system with synchronized EFI partitions.

## Features

- BTRFS RAID1 setup
- Full disk encryption with LUKS
- EFI partition synchronization
- Automated subvolume creation
- UUID-based configuration
- Network configuration (DHCP/Static)
- Minimal installation without desktop environment
- Built-in SSH server

## Requirements

- Debian Live System (booted in UEFI mode)
- Two identical disks for RAID1
- Internet connection for package installation

## Quick Start

1. Boot into a Debian Live System in UEFI mode
2. Install git and clone this repository:
   ```bash
   apt update
   apt install -y git
   git clone https://github.com/yourusername/debian-btrfs-raid
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

## Configuration

The script will prompt for:
- Disk selection (with UUID information)
- Partition sizes
- System configuration (hostname, username, timezone)
- Network configuration (DHCP/Static IP)
- LUKS encryption passwords

## Directory Structure

```
debian-btrfs-raid/
├── install.sh              # Main installation script
├── modules/               # Module directory
│   ├── utils.sh           # Utility functions
│   ├── config.sh          # Configuration handling
│   ├── network.sh         # Network setup
│   ├── disk.sh           # Disk operations
│   ├── btrfs.sh          # BTRFS setup
│   └── system.sh         # System installation
└── examples/             # Example configurations
    └── config.example    # Example configuration file
```

## Subvolume Layout

The script creates the following BTRFS subvolumes:
- @: Root filesystem
- @home: /home
- @var: /var
- @cache: /var/cache
- @tmp: /tmp
- @swap: Swap (if needed)

## Security Features

- Full disk encryption (LUKS2)
- Secure EFI handling
- No root SSH access
- Minimal package installation

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
