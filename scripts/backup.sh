#!/bin/bash

# Configuration files
CONFIG_FILE="backup_config.json"
USB_INFO_FILE="usb_info.json"

# Check for dependencies
command -v jq >/dev/null 2>&1 || { echo >&2 "jq is not installed. Aborting."; exit 1; }

# Load configurations
BACKUP_DIR=$(jq -r '.backup_directory' "$CONFIG_FILE")
USB_DEVICE=$(jq -r '.usb_device' "$USB_INFO_FILE")

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo "Backup directory $BACKUP_DIR does not exist. Creating it."
    mkdir -p "$BACKUP_DIR"
fi

# Mount the USB drive
MOUNT_POINT="/mnt/usb"
if ! mount | grep "$MOUNT_POINT" > /dev/null; then
    echo "Mounting USB device: $USB_DEVICE"
    sudo mount "$USB_DEVICE" "$MOUNT_POINT" || { echo "Failed to mount $USB_DEVICE"; exit 1; }
fi

# Create a backup
BACKUP_FILE="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).tar.gz"
echo "Creating backup in $BACKUP_FILE..."
tar -czf "$BACKUP_FILE" /path/to/data/to/backup || { echo "Backup creation failed."; exit 1; }

# Copy backup to USB
echo "Copying backup to USB..."
cp "$BACKUP_FILE" "$MOUNT_POINT/" || { echo "Failed to copy backup to USB."; exit 1; }

# Unmount the USB drive
echo "Unmounting USB device..."
sudo umount "$MOUNT_POINT" || { echo "Failed to unmount USB."; exit 1; }

# Log the backup
echo "Backup completed successfully on $(date)" >> "$BACKUP_DIR/backup_log.txt

# Notify user
echo "Backup process completed successfully!"
