#!/bin/bash

# Load configuration details
CONFIG_FILE="config/backup_config.json"
USB_MOUNT_POINT="/mnt/usb"
REMOTE_HOST=$(jq -r '.remote_host' "$CONFIG_FILE")
REMOTE_USER=$(jq -r '.remote_user' "$CONFIG_FILE")
REMOTE_PATH=$(jq -r '.remote_path' "$CONFIG_FILE")

# Check if USB is mounted
if ! mount | grep "$USB_MOUNT_POINT" > /dev/null; then
    echo "USB device not mounted. Please mount it first."
    exit 1
fi

# Perform SFTP upload
echo "Uploading files to $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH..."
sftp "$REMOTE_USER@$REMOTE_HOST" <<EOF
put $USB_MOUNT_POINT/backup_*.tar.gz $REMOTE_PATH/
bye
EOF

# Notify user
echo "Files uploaded to $REMOTE_HOST successfully."
