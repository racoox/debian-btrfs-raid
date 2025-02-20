#!/bin/bash
# network.sh - Network configuration functions

# Function to get network configuration
get_network_config() {
    log "Network Configuration"
    echo "--------------------"
    
    read -p "Network interface [$DEFAULT_NETWORK_IF]: " network_if
    CONFIG[network_if]=${network_if:-$DEFAULT_NETWORK_IF}
    
    while true; do
        read -p "Use DHCP? (y/n): " use_dhcp
        case $use_dhcp in
            [Yy]* )
                CONFIG[use_dhcp]="yes"
                break
                ;;
            [Nn]* )
                CONFIG[use_dhcp]="no"
                get_static_network_config
                break
                ;;
            * )
                warning "Please answer yes or no."
                ;;
        esac
    done
}

# Function to get static network configuration
get_static_network_config() {
    while true; do
        read -p "IP address (e.g., 192.168.1.100): " ip_address
        if validate_ip "$ip_address"; then
            CONFIG[ip_address]=$ip_address
            break
        fi
        warning "Invalid IP address format"
    done

    while true; do
        read -p "Netmask (e.g., 255.255.255.0): " netmask
        if validate_ip "$netmask"; then
            CONFIG[netmask]=$netmask
            break
        fi
        warning "Invalid netmask format"
    done

    while true; do
        read -p "Gateway (e.g., 192.168.1.1): " gateway
        if validate_ip "$gateway"; then
            CONFIG[gateway]=$gateway
            break
        fi
        warning "Invalid gateway format"
    done

    while true; do
        read -p "Primary DNS (e.g., 8.8.8.8): " dns1
        if validate_ip "$dns1"; then
            CONFIG[dns1]=$dns1
            break
        fi
        warning "Invalid DNS format"
    done

    read -p "Secondary DNS (optional, e.g., 8.8.4.4): " dns2
    if [ -n "$dns2" ]; then
        if validate_ip "$dns2"; then
            CONFIG[dns2]=$dns2
        else
            warning "Invalid DNS format, secondary DNS will be skipped"
        fi
    fi
}

# Function to configure network in the installed system
configure_network() {
    log "Configuring network..."
    
    # Create interfaces file
    cat << EOF > /mnt/etc/network/interfaces
# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto ${CONFIG[network_if]}
EOF

    if [ "${CONFIG[use_dhcp]}" = "yes" ]; then
        cat << EOF >> /mnt/etc/network/interfaces
iface ${CONFIG[network_if]} inet dhcp
EOF
    else
        cat << EOF >> /mnt/etc/network/interfaces
iface ${CONFIG[network_if]} inet static
    address ${CONFIG[ip_address]}
    netmask ${CONFIG[netmask]}
    gateway ${CONFIG[gateway]}
EOF

        # Configure DNS if static IP
        cat << EOF > /mnt/etc/resolv.conf
nameserver ${CONFIG[dns1]}
EOF
        [ -n "${CONFIG[dns2]}" ] && echo "nameserver ${CONFIG[dns2]}" >> /mnt/etc/resolv.conf
        
        # Make resolv.conf immutable to prevent overwriting
        chattr +i /mnt/etc/resolv.conf
    fi
}
