#!/bin/bash

# Load USB device information
USB_INFO_FILE="config/usb_info.json"
USB_DEVICE=$(jq -r '.usb_device' "$USB_INFO_FILE")
MOUNT_POINT="/mnt/usb"

# Check if USB device is already mounted
if mount | grep "$MOUNT_POINT" > /dev/null; then
    echo "USB device already mounted at $MOUNT_POINT."
else
    # Attempt to mount USB device
    echo "Mounting USB device: $USB_DEVICE..."
    sudo mount "$USB_DEVICE" "$MOUNT_POINT" || { echo "Failed to mount USB device."; exit 1; }
    echo "USB device mounted successfully at $MOUNT_POINT."
fi

# Notify user
echo "USB drive connected and mounted at $MOUNT_POINT."
