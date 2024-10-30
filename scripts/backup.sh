#!/bin/bash

# Load environment variables
if [ -f ".env" ]; then
    source .env
else
    echo ".env file not found. Aborting." | tee -a "logs/backup_log.txt"
    exit 1
fi

# Load configuration files
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

# Validate configurations
if [ -z "$BACKUP_DIR" ] || [ -z "$USB_DEVICE" ]; then
    echo "Backup directory or USB device not configured properly. Aborting." | tee -a "$LOG_FILE"
    exit 1
fi

# Validate USB mount point
MOUNT_POINT="/mnt/usb"
RETRY_COUNT=3

for attempt in $(seq 1 $RETRY_COUNT); do
    if grep -qs "$MOUNT_POINT" /proc/mounts; then
        echo "USB device is already mounted at $MOUNT_POINT." | tee -a "$LOG_FILE"
        break
    else
        echo "Mounting USB device: $USB_DEVICE (Attempt $attempt/$RETRY_COUNT)" | tee -a "$LOG_FILE"
        sudo mount "$USB_DEVICE" "$MOUNT_POINT" && break || sleep 5
    fi

    if [ "$attempt" -eq "$RETRY_COUNT" ]; then
        echo "Failed to mount $USB_DEVICE after $RETRY_COUNT attempts." | tee -a "$LOG_FILE"
        exit 1
    fi
done

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

# Encrypt backup (using GPG)
ENCRYPTED_BACKUP_FILE="${BACKUP_FILE}.gpg"
gpg --batch --yes --passphrase "$BACKUP_ENCRYPTION_PASSPHRASE" -c "$BACKUP_FILE" && rm "$BACKUP_FILE"
BACKUP_FILE="$ENCRYPTED_BACKUP_FILE"

# Verify backup file creation
if [ ! -f "$BACKUP_FILE" ]; then
    echo "Backup file $BACKUP_FILE could not be created. Aborting." | tee -a "$LOG_FILE"
    exit 1
fi

# Copy backup to USB with retry mechanism
for attempt in $(seq 1 $RETRY_COUNT); do
    echo "Copying backup to USB (Attempt $attempt/$RETRY_COUNT)..." | tee -a "$LOG_FILE"
    cp "$BACKUP_FILE" "$MOUNT_POINT/" && break || sleep 5

    if [ "$attempt" -eq "$RETRY_COUNT" ]; then
        echo "Failed to copy backup to USB after $RETRY_COUNT attempts." | tee -a "$LOG_FILE"
        exit 1
    fi
done

# Verify copy
if ! diff "$BACKUP_FILE" "$MOUNT_POINT/$(basename $BACKUP_FILE)" > /dev/null; then
    echo "Verification of copied backup failed. Aborting." | tee -a "$LOG_FILE"
    exit 1
fi

# Unmount the USB drive safely
echo "Unmounting USB device..." | tee -a "$LOG_FILE"
sudo umount "$MOUNT_POINT" || { echo "Failed to unmount USB." | tee -a "$LOG_FILE"; exit 1; }

# Log the backup completion
echo "Backup completed successfully on $(date)" | tee -a "$LOG_FILE"

# Notify user of completion
echo "Backup process completed successfully!" | tee -a "$LOG_FILE"
