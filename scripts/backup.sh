#!/bin/bash

# backup.sh
# This script handles the backup of files from the USB drive to the remote server over SFTP.

# Configuration
USB_MOUNT_POINT="/mnt/usb_drive"   # Change this to your USB mount point
BACKUP_DIR="/home/ubuntu/backups"   # Local backup directory
REMOTE_USER="ubuntu"                 # Remote SSH user
REMOTE_HOST="15.223.3.155"           # Remote server IP address
REMOTE_DIR="/remote/backup/path"     # Remote backup directory

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Check if USB is mounted
if mount | grep $USB_MOUNT_POINT > /dev/null; then
    echo "USB drive is mounted."

    # Create a timestamp
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

    # Create a backup file name
    BACKUP_FILE="$BACKUP_DIR/backup_$TIMESTAMP.tar.gz"

    # Create a backup of the USB drive
    tar -czf $BACKUP_FILE -C $USB_MOUNT_POINT .

    # Upload backup to remote server
    sftp $REMOTE_USER@$REMOTE_HOST << EOF
    put $BACKUP_FILE $REMOTE_DIR
    bye
EOF

    echo "Backup completed successfully and uploaded to remote server."

else
    echo "Error: USB drive is not mounted."
    exit 1
fi
