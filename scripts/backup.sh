#!/bin/bash

# backup.sh - Main backup script for USB drive backup
# Description: Automates the backup of data to a USB drive, including error handling, logging, and system integrity checks.

# Configuration files
CONFIG_FILE="config/backup_config.json"
USB_INFO_FILE="config/usb_info.json"
LOG_FILE="logs/backup_log.txt"

# Ensure jq is installed
command -v jq >/dev/null 2>&1 || { echo "jq is not installed. Aborting." | tee -a "$LOG_FILE"; exit 1; }

# Load configurations
BACKUP_DIR=$(jq -r '.backup_directory' "$CONFIG_FILE")
USB_DEVICE=$(jq -r '.usb_device' "$USB_INFO_FILE")
INCLUDE_PATHS=$(jq -r '.include_paths[]' "$CONFIG_FILE")
EXCLUDE_PATHS=$(jq -r '.exclude_paths[]' "$CONFIG_FILE")

# Validate USB mount point
MOUNT_POINT="/mnt/usb"
if ! grep -qs "$MOUNT_POINT" /proc/mounts; then
    echo "Mounting USB device: $USB_DEVICE" | tee -a "$LOG_FILE"
    sudo mount "$USB_DEVICE" "$MOUNT_POINT" || { echo "Failed to mount $USB_DEVICE" | tee -a "$LOG_FILE"; exit 1; }
else
    echo "USB device is already mounted at $MOUNT_POINT." | tee -a "$LOG_FILE"
fi

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo "Backup directory $BACKUP_DIR does not exist. Creating it." | tee -a "$LOG_FILE"
    mkdir -p "$BACKUP_DIR" || { echo "Failed to create backup directory $BACKUP_DIR" | tee -a "$LOG_FILE"; exit 1; }
fi

# Create a backup
BACKUP_FILE="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).tar.gz"
echo "Creating backup in $BACKUP_FILE..." | tee -a "$LOG_FILE"

# Use tar with includes and excludes
tar -czf "$BACKUP_FILE" $(for path in $INCLUDE_PATHS; do echo "$path"; done) $(for path in $EXCLUDE_PATHS; do echo "--exclude=$path"; done) \
    || { echo "Backup creation failed." | tee -a "$LOG_FILE"; exit 1; }

# Copy backup to USB
echo "Copying backup to USB..." | tee -a "$LOG_FILE"
cp "$BACKUP_FILE" "$MOUNT_POINT/" || { echo "Failed to copy backup to USB." | tee -a "$LOG_FILE"; exit 1; }

# Unmount the USB drive safely
echo "Unmounting USB device..." | tee -a "$LOG_FILE"
sudo umount "$MOUNT_POINT" || { echo "Failed to unmount USB." | tee -a "$LOG_FILE"; exit 1; }

# Log the backup completion
echo "Backup completed successfully on $(date)" | tee -a "$LOG_FILE"

# Notify user of completion
echo "Backup process completed successfully!" | tee -a "$LOG_FILE"
