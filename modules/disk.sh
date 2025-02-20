#!/bin/bash
# disk.sh - Disk preparation and encryption functions

prepare_disks() {
    log "Preparing disks..."
    
    # Aggressively wipe all signatures and data
    for disk in "${CONFIG[disk1]}" "${CONFIG[disk2]}"; do
        log "Wiping disk $disk..."
        # Clear any existing LUKS headers
        cryptsetup erase "$disk" || true
        # Clear any existing filesystem signatures
        wipefs -af "$disk"
        # Zero out the first and last 100MB of the disk
        dd if=/dev/zero of="$disk" bs=1M count=100
        dd if=/dev/zero of="$disk" bs=1M count=100 seek=$(($(($(blockdev --getsize64 "$disk") / 1024 / 1024)) - 100))
        # Clear partition table
        sgdisk -Z "$disk"
    done
    
    # Create new GPT partition tables
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
    
    # Force kernel to reread partition tables
    partprobe "${CONFIG[disk1]}"
    partprobe "${CONFIG[disk2]}"
    
    sleep 2  # Give the system time to recognize new partitions
}

setup_encryption() {
    log "Setting up LUKS encryption..."
    local attempts=0
    local password
    local confirm_password
    local confirm
    local cryptname1="${CONFIG[hostname]}-crypt1"
    local cryptname2="${CONFIG[hostname]}-crypt2"
    
    while [ $attempts -lt 3 ]; do
        attempts=$((attempts + 1))
        log "Attempt $attempts of 3: Setting up encryption"
        
        read -p "This will encrypt your disks. Are you sure? (Type 'YES' to continue): " confirm
        if [ "$confirm" = "YES" ]; then
            # Get and confirm password
            echo -n "Enter LUKS encryption password: "
            read -s password
            echo
            echo -n "Confirm LUKS encryption password: "
            read -s confirm_password
            echo

            if [ "$password" = "$confirm_password" ]; then
                # Create LUKS containers with force option
                if echo -n "$password" | cryptsetup luksFormat --type luks2 "${CONFIG[disk1]}2" --force -; then
                    echo -n "$password" | cryptsetup luksFormat --type luks2 "${CONFIG[disk2]}2" --force -
                    echo -n "$password" | cryptsetup open "${CONFIG[disk1]}2" "$cryptname1" -
                    echo -n "$password" | cryptsetup open "${CONFIG[disk2]}2" "$cryptname2" -
                    
                    CONFIG[luks1_uuid]=$(cryptsetup luksUUID "${CONFIG[disk1]}2")
                    CONFIG[luks2_uuid]=$(cryptsetup luksUUID "${CONFIG[disk2]}2")
                    CONFIG[cryptname1]=$cryptname1
                    CONFIG[cryptname2]=$cryptname2
                    
                    log "Encryption setup completed successfully"
                    return 0
                fi
            else
                warning "Passwords do not match. Please try again."
            fi
        else
            warning "Please type 'YES' in capital letters to confirm encryption setup"
        fi

        if [ $attempts -eq 3 ]; then
            error "Failed to set up encryption after 3 attempts"
        fi
    done
}
