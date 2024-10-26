#!/bin/bash

# Load environment variables
source .env

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

# Perform SFTP upload with improved error handling
echo "Uploading files to $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH..."

# Using a loop to retry the SFTP upload up to 3 times if it fails
for i in {1..3}; do
    sftp -i "$SFTP_PRIVATE_KEY" "$REMOTE_USER@$REMOTE_HOST" <<EOF
put $USB_MOUNT_POINT/backup_*.tar.gz $REMOTE_PATH/
bye
EOF

    if [ $? -eq 0 ]; then
        echo "Files uploaded to $REMOTE_HOST successfully."
        break
    else
        echo "Attempt $i: Failed to upload files to $REMOTE_HOST. Retrying in 5 seconds..."
        sleep 5
    fi

    if [ $i -eq 3 ]; then
        echo "Error: Upload failed after 3 attempts."
        exit 1
    fi
done

# Notify user if upload is successful
echo "Backup upload completed successfully."
