#!/bin/bash

# Configuration file for USB connection
USB_INFO_FILE="config/usb_info.json"

# Load USB device information
USB_DEVICE=$(jq -r '.usb_device' "$USB_INFO_FILE")
MOUNT_POINT=$(jq -r '.mount_point' "$USB_INFO_FILE")

# Check if 'jq' is installed
command -v jq >/dev/null 2>&1 || { echo >&2 "jq is not installed. Please install jq to proceed."; exit 1; }

# Ensure USB device and mount point are provided
if [ -z "$USB_DEVICE" ] || [ -z "$MOUNT_POINT" ]; then
    echo "USB device or mount point information is missing in $USB_INFO_FILE. Please check the configuration."
    exit 1
fi

# Create mount point directory if it doesn't exist
if [ ! -d "$MOUNT_POINT" ]; then
    echo "Mount point $MOUNT_POINT does not exist. Creating it."
    sudo mkdir -p "$MOUNT_POINT"
fi

# Check if the USB device is already mounted
if mount | grep "$MOUNT_POINT" > /dev/null; then
    echo "USB device is already mounted at $MOUNT_POINT."
else
    # Attempt to mount the USB device
    echo "Mounting USB device: $USB_DEVICE..."
    sudo mount "$USB_DEVICE" "$MOUNT_POINT" || { echo "Failed to mount $USB_DEVICE. Please check the device and try again."; exit 1; }
    echo "USB device mounted successfully at $MOUNT_POINT."
fi

# Notify user of successful connection
echo "You can now access the USB drive at $MOUNT_POINT."
