#!/bin/bash
# disk.sh - Disk preparation and encryption functions

# Function to prepare disks
prepare_disks() {
    log "Preparing disks..."
    
    # Clear disk signatures
    wipefs -af "${CONFIG[disk1]}"
    wipefs -af "${CONFIG[disk2]}"
    
    # Create GPT partition tables
    sgdisk -Z "${CONFIG[disk1]}"
    sgdisk -Z "${CONFIG[disk2]}"
    
    # Create partitions on first disk
    if [ "${CONFIG[root_size]}" = "0" ]; then
        # Use remaining space for root
        sgdisk -n 1:0:+${CONFIG[efi_size]} -t 1:ef00 "${CONFIG[disk1]}"  # EFI partition
        sgdisk -n 2:0:0 -t 2:8309 "${CONFIG[disk1]}"                     # BTRFS partition (Linux LUKS)
    else
        # Use specified size for root
        sgdisk -n 1:0:+${CONFIG[efi_size]} -t 1:ef00 "${CONFIG[disk1]}"  # EFI partition
        sgdisk -n 2:0:+${CONFIG[root_size]} -t 2:8309 "${CONFIG[disk1]}" # BTRFS partition (Linux LUKS)
    fi
    
    # Clone partition table to second disk
    sgdisk -R "${CONFIG[disk2]}" "${CONFIG[disk1]}"
    sgdisk -G "${CONFIG[disk2]}"  # Randomize disk GUID
    
    # Format EFI partitions
    mkfs.fat -F 32 "${CONFIG[disk1]}1"
    mkfs.fat -F 32 "${CONFIG[disk2]}1"
}

# Function to setup disk encryption
setup_encryption() {
    log "Setting up LUKS encryption..."
    
    # Create LUKS containers
    cryptsetup luksFormat --type luks2 "${CONFIG[disk1]}2"
    cryptsetup luksFormat --type luks2 "${CONFIG[disk2]}2"
    
    # Open LUKS containers
    cryptsetup open "${CONFIG[disk1]}2" cryptroot1
    cryptsetup open "${CONFIG[disk2]}2" cryptroot2
    
    # Store UUIDs for later use
    CONFIG[luks1_uuid]=$(cryptsetup luksUUID "${CONFIG[disk1]}2")
    CONFIG[luks2_uuid]=$(cryptsetup luksUUID "${CONFIG[disk2]}2")
}

# Function to setup EFI synchronization
setup_efi_sync() {
    log "Setting up EFI synchronization..."
    
    mkdir -p /mnt/etc/systemd/system
    
    # Create service file
    cat << EOF > /mnt/etc/systemd/system/efi-sync.service
[Unit]
Description=Sync EFI partitions
RequiresMountsFor=/boot/efi

[Service]
Type=oneshot
ExecStartPre=/bin/mkdir -p /boot/efi2
ExecStartPre=/bin/mount UUID=$(blkid -s UUID -o value "${CONFIG[disk2]}1") /boot/efi2
ExecStart=/usr/bin/rsync -av --delete /boot/efi/ /boot/efi2/
ExecStop=/bin/umount /boot/efi2
ExecStop=/bin/rmdir /boot/efi2

[Install]
WantedBy=multi-user.target
EOF

    # Create path unit
    cat << EOF > /mnt/etc/systemd/system/efi-sync.path
[Unit]
Description=Monitor EFI partition for changes

[Path]
PathModified=/boot/efi
Unit=efi-sync.service

[Install]
WantedBy=multi-user.target
EOF

    # Add secondary EFI to fstab
    UUID2=$(blkid -s UUID -o value "${CONFIG[disk2]}1")
    echo "UUID=$UUID2  /boot/efi2  vfat  noauto,umask=0077  0  0" >> /mnt/etc/fstab
}
