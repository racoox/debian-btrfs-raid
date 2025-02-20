#!/bin/bash
# system.sh - System installation and configuration functions

# Function to install base system
install_base_system() {
    log "Installing base system..."
    
    # Bootstrap Debian
    debootstrap --arch amd64 bookworm /mnt http://deb.debian.org/debian
    
    # Mount virtual filesystems
    mount -t proc proc /mnt/proc
    mount -t sysfs sys /mnt/sys
    mount -o bind /dev /mnt/dev
    mount -o bind /dev/pts /mnt/dev/pts
    
    # Copy resolv.conf
    cp /etc/resolv.conf /mnt/etc/resolv.conf
    
    # Generate fstab
    generate_fstab
}

# Function to configure system
configure_system() {
    log "Configuring system..."
    
    # Set hostname
    echo "${CONFIG[hostname]}" > /mnt/etc/hostname
    
    # Set timezone
    ln -sf "/usr/share/zoneinfo/${CONFIG[timezone]}" /mnt/etc/localtime
    
    # Configure encryption
    configure_encryption
    
    # Prepare chroot command
    cat << EOF > /mnt/chroot-setup.sh
#!/bin/bash
set -e

# Update package lists
apt update

# Install minimal system packages
apt install -y --no-install-recommends \
    linux-image-amd64 \
    grub-efi-amd64 \
    efibootmgr \
    btrfs-progs \
    cryptsetup \
    cryptsetup-initramfs \
    openssh-server \
    sudo \
    vim-tiny \
    systemd-sysv \
    ifupdown \
    net-tools

# Create user and add to sudo
useradd -m -s /bin/bash "${CONFIG[username]}"
usermod -aG sudo "${CONFIG[username]}"

# Set root password
echo "Set root password:"
passwd

# Set user password
echo "Set password for ${CONFIG[username]}:"
passwd "${CONFIG[username]}"

# Install and configure GRUB
grub-install --target=x86_64-efi --efi-directory=/boot/efi \
    --bootloader-id=debian --recheck
grub-install --target=x86_64-efi --efi-directory=/boot/efi \
    --bootloader-id=debian --recheck
update-grub

# Enable services
systemctl enable ssh
systemctl enable efi-sync.path

# Configure SSH
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config

# Clean up
apt clean
apt autoremove --purge -y
EOF

    # Make script executable and run it in chroot
    chmod +x /mnt/chroot-setup.sh
    chroot /mnt /chroot-setup.sh
    rm /mnt/chroot-setup.sh
    
    log "System configuration complete"
}

# Function to configure encryption
configure_encryption() {
    log "Configuring encryption..."
    
    # Add crypttab entries
    cat << EOF > /mnt/etc/crypttab
# <target name>    <source device>                              <key file>  <options>
${CONFIG[cryptname1]}  UUID=${CONFIG[luks1_uuid]}  none  luks,discard
${CONFIG[cryptname2]}  UUID=${CONFIG[luks2_uuid]}  none  luks,discard
EOF

    # Configure initramfs for encryption
    cat << EOF > /mnt/etc/cryptsetup-initramfs/conf-hook
CRYPTSETUP=y
EOF

    # Update GRUB configuration
    cat << EOF >> /mnt/etc/default/grub
GRUB_ENABLE_CRYPTODISK=y
GRUB_CMDLINE_LINUX="cryptdevice=UUID=${CONFIG[luks1_uuid]}:${CONFIG[cryptname1]} cryptdevice=UUID=${CONFIG[luks2_uuid]}:${CONFIG[cryptname2]} root=/dev/mapper/${CONFIG[cryptname1]}"
EOF

    # Update initramfs
    chroot /mnt update-initramfs -u -k all
}
