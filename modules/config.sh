#!/bin/bash
# config.sh - Configuration handling

# Declare CONFIG as associative array
declare -A CONFIG

# Default configuration values
DEFAULT_HOSTNAME="debian"
DEFAULT_USERNAME="user"
DEFAULT_TIMEZONE="Europe/Paris"
DEFAULT_NETWORK_IF="eth0"
DEFAULT_EFI_SIZE="512M"
DEFAULT_ROOT_SIZE="0" # 0 means use all remaining space

# Function to list available disks with numbers
list_available_disks() {
    log "Available disks:"
    printf "%-4s %-10s %-8s %-25s %-40s\n" "No." "Device" "Size" "Model" "UUID"
    echo "------------------------------------------------------------------------------------------------"
    local i=1
    local disks=()
    
    # First list SATA/SAS disks
    while read -r disk; do
        if [[ $disk =~ ^sd && ! $disk =~ ^sdc ]]; then  # Exclude sdc which is your USB
            disks+=("$disk")
            local size model uuid
            size=$(lsblk -dno SIZE "/dev/$disk" 2>/dev/null)
            model=$(lsblk -dno MODEL "/dev/$disk" 2>/dev/null)
            uuid=$(blkid -s UUID -o value "/dev/$disk" 2>/dev/null || echo "none")
            printf "%-4s %-10s %-8s %-25s %-40s\n" "[$i]" "/dev/$disk" "$size" "$model" "$uuid"
            i=$((i + 1))
        fi
    done < <(lsblk -dno NAME)

    # Then list NVMe disks
    while read -r disk; do
        if [[ $disk =~ ^nvme && ! $disk =~ ^nvme2n1 ]]; then  # Exclude nvme2n1 which is 8G
            disks+=("$disk")
            local size model uuid
            size=$(lsblk -dno SIZE "/dev/$disk" 2>/dev/null)
            model=$(lsblk -dno MODEL "/dev/$disk" 2>/dev/null)
            uuid=$(blkid -s UUID -o value "/dev/$disk" 2>/dev/null || echo "none")
            printf "%-4s %-10s %-8s %-25s %-40s\n" "[$i]" "/dev/$disk" "$size" "$model" "$uuid"
            i=$((i + 1))
        fi
    done < <(lsblk -dno NAME)
    
    echo "------------------------------------------------------------------------------------------------"
    echo
    
    CONFIG[available_disks]="${disks[*]}"
    CONFIG[disk_count]=$((i - 1))
}

# Function to get disk by number
get_disk_by_number() {
    local number=$1
    local -a disks
    read -ra disks <<< "${CONFIG[available_disks]}"
    if [[ "$number" =~ ^[0-9]+$ ]] && [ "$number" -ge 1 ] && [ "$number" -le "${CONFIG[disk_count]}" ]; then
        echo "/dev/${disks[$((number-1))]}"
        return 0
    fi
    return 1
}

# Function to validate hostname
validate_hostname() {
    local hostname=$1
    if [[ "$hostname" =~ ^[a-zA-Z0-9][-a-zA-Z0-9]*[a-zA-Z0-9]$ ]]; then
        return 0
    fi
    return 1
}

# Function to validate size format
validate_size() {
    local size=$1
    if [[ $size =~ ^[0-9]+[MGT]$ ]]; then
        return 0
    elif [ "$size" = "0" ]; then
        return 0
    else
        return 1
    fi
}

# Function to get disk configuration
get_disk_config() {
    log "Disk Configuration"
    echo "-------------------"
    
    list_available_disks
    
    # First disk selection
    while true; do
        read -p "Select first disk (enter number): " disk_number
        if disk_path=$(get_disk_by_number "$disk_number"); then
            CONFIG[disk1]=$disk_path
            break
        fi
        warning "Invalid disk number. Please select a number from the list."
    done

    # Second disk selection
    while true; do
        read -p "Select second disk (enter number): " disk_number
        if disk_path=$(get_disk_by_number "$disk_number"); then
            if [ "$disk_path" != "${CONFIG[disk1]}" ]; then
                CONFIG[disk2]=$disk_path
                break
            else
                warning "Cannot use the same disk twice"
            fi
        else
            warning "Invalid disk number. Please select a number from the list."
        fi
    done

    # Partition sizes
    while true; do
        read -p "EFI partition size [$DEFAULT_EFI_SIZE]: " efi_size
        efi_size=${efi_size:-$DEFAULT_EFI_SIZE}
        if validate_size "$efi_size"; then
            CONFIG[efi_size]=$efi_size
            break
        fi
        warning "Invalid size format. Use number followed by M, G, or T (e.g., 512M, 1G)"
    done

    while true; do
        read -p "Root partition size (0 for remaining space) [$DEFAULT_ROOT_SIZE]: " root_size
        root_size=${root_size:-$DEFAULT_ROOT_SIZE}
        if validate_size "$root_size"; then
            CONFIG[root_size]=$root_size
            break
        fi
        warning "Invalid size format. Use number followed by M, G, or T (e.g., 20G, 1T) or 0 for remaining space"
    done
}

# Function to get system configuration
get_system_config() {
    log "System Configuration"
    echo "-------------------"
    
    while true; do
        read -p "Hostname [$DEFAULT_HOSTNAME]: " hostname
        hostname=${hostname:-$DEFAULT_HOSTNAME}
        if validate_hostname "$hostname"; then
            CONFIG[hostname]=$hostname
            break
        fi
        warning "Invalid hostname. Use alphanumeric characters and hyphens (not at start/end)"
    done
    
    read -p "Username [$DEFAULT_USERNAME]: " username
    CONFIG[username]=${username:-$DEFAULT_USERNAME}
    
    read -p "Timezone [$DEFAULT_TIMEZONE]: " timezone
    CONFIG[timezone]=${timezone:-$DEFAULT_TIMEZONE}
}

# Function to show configuration summary
show_config_summary() {
    log "Configuration Summary"
    echo "-------------------"
    echo "System Settings:"
    echo "  Hostname: ${CONFIG[hostname]}"
    echo "  Username: ${CONFIG[username]}"
    echo "  Timezone: ${CONFIG[timezone]}"
    echo
    echo "Disk Settings:"
    echo "  Disk 1: ${CONFIG[disk1]}"
    echo "  Disk 2: ${CONFIG[disk2]}"
    echo "  EFI Size: ${CONFIG[efi_size]}"
    if [ "${CONFIG[root_size]}" = "0" ]; then
        echo "  Root Size: Remaining space"
    else
        echo "  Root Size: ${CONFIG[root_size]}"
    fi
    echo
    echo "Network Settings:"
    echo "  Interface: ${CONFIG[network_if]}"
    echo "  DHCP: ${CONFIG[use_dhcp]}"
    if [ "${CONFIG[use_dhcp]}" = "no" ]; then
        echo "  IP Address: ${CONFIG[ip_address]}"
        echo "  Netmask: ${CONFIG[netmask]}"
        echo "  Gateway: ${CONFIG[gateway]}"
        echo "  Primary DNS: ${CONFIG[dns1]}"
        [ -n "${CONFIG[dns2]}" ] && echo "  Secondary DNS: ${CONFIG[dns2]}"
    fi
    echo
}
