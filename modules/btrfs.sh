#!/bin/bash
# btrfs.sh - BTRFS setup and configuration functions

# Function to setup BTRFS RAID1
setup_btrfs_raid() {
    log "Creating BTRFS RAID1..."
    mkfs.btrfs -f -d raid1 -m raid1 /dev/mapper/cryptroot1 /dev/mapper/cryptroot2
}

# Function to create BTRFS subvolumes
create_subvolumes() {
    log "Creating BTRFS subvolumes..."
    
    # Mount BTRFS root
    mount /dev/mapper/cryptroot1 /mnt
    
    # Create subvolumes
    local subvolumes=("@" "@home" "@var" "@cache" "@tmp" "@swap")
    for subvol in "${subvolumes[@]}"; do
        btrfs subvolume create "/mnt/$subvol"
    done
    
    # Unmount for remounting with subvolumes
    umount /mnt
}

# Function to mount BTRFS subvolumes
mount_subvolumes() {
    log "Mounting BTRFS subvolumes..."
    
    local mount_opts="compress=zstd,space_cache=v2,autodefrag"
    
    # Get UUIDs
    local BTRFS_UUID=$(blkid -s UUID -o value /dev/mapper/cryptroot1)
    local EFI_UUID=$(blkid -s UUID -o value "${CONFIG[disk1]}1")
    
    # Mount root subvolume
    mount -o "subvol=@,$mount_opts" /dev/mapper/cryptroot1 /mnt
    
    # Create mount points
    mkdir -p /mnt/{home,var,var/cache,tmp,boot/efi}
    
    # Mount other subvolumes
    mount -o "subvol=@home,$mount_opts" /dev/mapper/cryptroot1 /mnt/home
    mount -o "subvol=@var,$mount_opts" /dev/mapper/cryptroot1 /mnt/var
    mount -o "subvol=@cache,$mount_opts" /dev/mapper/cryptroot1 /mnt/var/cache
    mount -o "subvol=@tmp,$mount_opts" /dev/mapper/cryptroot1 /mnt/tmp
    
    # Mount EFI partition
    mount UUID=$EFI_UUID /mnt/boot/efi
}

# Function to generate fstab with UUIDs
generate_fstab() {
    log "Generating fstab with UUIDs..."
    
    local BTRFS_UUID=$(blkid -s UUID -o value /dev/mapper/cryptroot1)
    local EFI_UUID=$(blkid -s UUID -o value "${CONFIG[disk1]}1")
    local mount_opts="defaults,compress=zstd,space_cache=v2,autodefrag"
    
    # Create fstab
    cat << EOF > /mnt/etc/fstab
# /etc/fstab: static file system information
#
# Use 'blkid' to print the universally unique identifier for a device
# <file system>                           <mount point>  <type>  <options>  <dump>  <pass>

# BTRFS root on LUKS
UUID=$BTRFS_UUID  /               btrfs   subvol=@,$mount_opts              0       0

# BTRFS subvolumes
UUID=$BTRFS_UUID  /home          btrfs   subvol=@home,$mount_opts          0       0
UUID=$BTRFS_UUID  /var           btrfs   subvol=@var,$mount_opts           0       0
UUID=$BTRFS_UUID  /var/cache     btrfs   subvol=@cache,$mount_opts         0       0
UUID=$BTRFS_UUID  /tmp           btrfs   subvol=@tmp,$mount_opts           0       0

# EFI partition
UUID=$EFI_UUID    /boot/efi      vfat    umask=0077                        0       2

# Swap subvolume (if needed)
#UUID=$BTRFS_UUID  /swap          btrfs   subvol=@swap,$mount_opts          0       0
EOF
}
