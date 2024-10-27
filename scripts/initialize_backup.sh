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
SSH_KEY_PATH=$(pass backup/ssh_key_path)

# Check for dependencies
command -v jq >/dev/null 2>&1 || { logger -p user.err "jq is not installed. Aborting."; exit 1; }

# Google OAuth2 setup for access
ACCESS_TOKEN=$(pass backup/google_access_token)

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

# Load device information
NUM_DEVICES=$(jq '.devices | length' "$STORAGE_DEVICES_FILE")

# Process each device
for (( i=0; i<$NUM_DEVICES; i++ )); do
    IS_ENABLED=$(jq -r ".devices[$i].is_enabled" "$STORAGE_DEVICES_FILE")

    # Skip devices that are not enabled
    if [ "$IS_ENABLED" != "true" ]; then
        continue
    fi

    DEVICE_PATH=$(jq -r ".devices[$i].device_path" "$STORAGE_DEVICES_FILE")
    MOUNT_POINT=$(jq -r ".devices[$i].mount_point" "$STORAGE_DEVICES_FILE")
    DEVICE_TYPE=$(jq -r ".devices[$i].device_type" "$STORAGE_DEVICES_FILE")

    # Mount device
    mount_device "$DEVICE_PATH" "$MOUNT_POINT" "$DEVICE_TYPE"
done

# Notify user that all devices have been processed
logger -p user.info "Device processing complete."

# Google OAuth2 Integration - Notify remote backup location access using email accounts
send_oauth_notification() {
    local access_token=$1
    local email=$2
    curl -X POST \
        -H "Authorization: Bearer $access_token" \
        -H "Content-Type: application/json" \
        -d '{
            "message": {
                "subject": "Backup System - Remote Access Notification",
                "body": {
                    "contentType": "Text",
                    "content": "You have been granted access to the remote backup system."
                },
                "toRecipients": [
                    {
                        "emailAddress": {
                            "address": "'"$email"'"
                        }
                    }
                ]
            }
        }' "https://gmail.googleapis.com/upload/gmail/v1/users/me/messages/send"
}

# Grant access to the backup remote location
for email in "beseymoh@gmail.com" "beseymoh1@gmail.com" "adamabesey@gmail.com" "casecraftedshop@gmail.com"; do
    send_oauth_notification "$ACCESS_TOKEN" "$email"
done
