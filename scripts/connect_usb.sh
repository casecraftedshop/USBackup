#!/bin/bash

# Configuration file for USB connection
USB_INFO_FILE="usb_info.json"

# Load USB device information
USB_DEVICE=$(jq -r '.usb_device' "$USB_INFO_FILE")

# Mount point
MOUNT_POINT="/mnt/usb"

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
