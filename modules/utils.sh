#!/bin/bash
# utils.sh - Common utility functions

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check if script is run as root
check_root() {
    if [ "$(id -u)" != "0" ]; then
        error "This script must be run as root"
    fi
}

# Function to check if running in UEFI mode
check_uefi() {
    if [ ! -d "/sys/firmware/efi" ]; then
        error "System not booted in UEFI mode"
    fi
}

# Function to validate IP address
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        for i in {1..4}; do
            if [ $(echo "$ip" | cut -d. -f$i) -gt 255 ]; then
                return 1
            fi
        done
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

# Function to confirm action
confirm_proceed() {
    local prompt=${1:-"Continue?"}
    read -p "$prompt (y/N) " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        error "Operation cancelled by user"
    fi
}
