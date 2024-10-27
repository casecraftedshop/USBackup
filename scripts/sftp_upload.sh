#!/bin/bash

set -e  # Exit on error
set -u  # Treat unset variables as error
set -o pipefail  # Fail on first failure in a pipe

# Trap to ensure .env file is removed after script execution
trap 'rm -f .env' EXIT

# Load and decrypt the .env file (ensure to remove after usage)
if [ -f ".env.gpg" ]; then
    gpg -d .env.gpg > .env
fi

# Source the environment variables
if [ -f ".env" ]; then
    source .env
else
    logger -p user.err "ERROR: .env file not found. Aborting."
    exit 1
fi

# Configuration file for storage devices
STORAGE_DEVICES_FILE="config/storage_devices.json"
RETRY_COUNT=3

# Example of retrieving sensitive information securely using `pass`
NETWORK_PASSWORD=$(pass backup/network_password)

# Check for dependencies
command -v jq >/dev/null 2>&1 || { logger -p user.err "jq is not installed. Aborting."; exit 1; }

# Function to mount devices
mount_device() {
    local device_path=$1
    local mount_point=$2
    local device_type=$3

    # Retry mechanism for mounting
    for attempt in $(seq 1 $RETRY_COUNT); do
        if [ "$device_type" == "Network" ]; then
            logger -p user.info "Attempt $attempt/$RETRY_COUNT: Mounting network drive $device_path at $mount_point."
            mount -t cifs "$device_path" "$mount_point" -o username="$NETWORK_USERNAME",password="$NETWORK_PASSWORD",rw && \
            logger -p user.info "Network drive mounted successfully." && break || sleep 5
        else
            logger -p user.info "Attempt $attempt/$RETRY_COUNT: Mounting $device_type $device_path at $mount_point."
            mount "$device_path" "$mount_point" && \
            logger -p user.info "$device_type mounted successfully." && break || sleep 5
        fi

        if [ "$attempt" -eq "$RETRY_COUNT" ]; then
            logger -p user.err "Failed to mount $device_path after $RETRY_COUNT attempts."
        fi
    done
}

# Notify user that all devices have been processed
logger -p user.info "Device processing complete."
