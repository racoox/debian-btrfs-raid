#!/bin/bash

# Exit on error
set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$SCRIPT_DIR/modules"

# Check if modules directory exists
if [ ! -d "$MODULE_DIR" ]; then
    echo "Error: modules directory not found!"
    exit 1
fi

# Source all modules
for module in "$MODULE_DIR"/*.sh; do
    if [ -f "$module" ]; then
        source "$module"
    fi
done

# Check requirements
check_requirements() {
    local required_packages=(
        "cryptsetup"
        "btrfs-progs"
        "gdisk"
        "rsync"
    )

    local missing_packages=()
    for pkg in "${required_packages[@]}"; do
        if ! command -v "$pkg" >/dev/null 2>&1; then
            missing_packages+=("$pkg")
        fi
    done

    if [ ${#missing_packages[@]} -ne 0 ]; then
        log "Installing required packages..."
        apt update
        apt install -y "${missing_packages[@]}"
    fi
}

# Main installation flow
main() {
    # Check if running as root
    check_root
    
    # Check if booted in UEFI mode
    check_uefi
    
    # Check and install requirements
    check_requirements
    
    log "Starting Debian BTRFS RAID1 Installation"
    
    # Get configurations
    get_system_config
    get_disk_config
    get_network_config
    
    # Show configuration summary
    show_config_summary
    
    # Confirm before proceeding
    echo
    read -p "Start installation? (y/N) " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        error "Installation cancelled by user"
    fi
    
    # Begin installation
    prepare_disks
    setup_encryption
    setup_btrfs_raid
    create_subvolumes
    mount_subvolumes
    install_base_system
    configure_network
    setup_efi_sync
    configure_system
    
    log "Installation complete!"
    log "You can now reboot into your new system."
    log "Remember your encryption passwords!"
}

# Run main if script is executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
