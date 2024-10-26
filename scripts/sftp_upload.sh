#!/bin/bash

# Configuration file for SFTP upload
BACKUP_CONFIG_FILE="backup_config.json"
BACKUP_LOG_FILE="backup_log.txt"
USB_MOUNT_POINT="/mnt/usb"

# Load configuration details
REMOTE_HOST=$(jq -r '.remote_host' "$BACKUP_CONFIG_FILE")
REMOTE_USER=$(jq -r '.remote_user' "$BACKUP_CONFIG_FILE")
REMOTE_PATH=$(jq -r '.remote_path' "$BACKUP_CONFIG_FILE")

# Check if USB is mounted
if ! mount | grep "$USB_MOUNT_POINT" > /dev/null; then
    echo "USB device is not mounted. Please mount it first."
    exit 1
fi

# Perform SFTP upload
echo "Starting SFTP upload from $USB_MOUNT_POINT to $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH..."

# Log the start time
echo "Upload started at $(date)" >> "$BACKUP_LOG_FILE"

# Use SFTP for file upload
sftp "$REMOTE_USER@$REMOTE_HOST" <<EOF
put $USB_MOUNT_POINT/* $REMOTE_PATH/
bye
EOF

# Check exit status of SFTP command
if [ $? -eq 0 ]; then
    echo "Files uploaded successfully."
    echo "Upload completed at $(date)" >> "$BACKUP_LOG_FILE"
else
    echo "Error during upload. Please check the log for details."
    echo "Upload failed at $(date)" >> "$BACKUP_LOG_FILE"
    exit 1
fi
