#!/bin/bash

# Configuration file for storage devices
STORAGE_DEVICES_FILE="config/storage_devices.json"
LOG_FILE="logs/connect_storage.log"

# Check for dependencies
command -v jq >/dev/null 2>&1 || { echo >&2 "jq is not installed. Aborting."; exit 1; }

# Load device information
NUM_DEVICES=$(jq '.devices | length' "$STORAGE_DEVICES_FILE")

# Process each device
for (( i=0; i<$NUM_DEVICES; i++ )); do
  IS_ENABLED=$(jq -r ".devices[$i].is_enabled" "$STORAGE_DEVICES_FILE")

  # Skip devices that are not enabled
  if [ "$IS_ENABLED" != "true" ]; then
    continue
  fi

  DEVICE_PATH=$(jq -r ".devices[$i].device_path" "$STORAGE_DEVICES_FILE")
  MOUNT_POINT=$(jq -r ".devices[$i].mount_point" "$STORAGE_DEVICES_FILE")
  DEVICE_TYPE=$(jq -r ".devices[$i].device_type" "$STORAGE_DEVICES_FILE")
  ENCRYPTION=$(jq -r ".devices[$i].encryption" "$STORAGE_DEVICES_FILE")

  # Handle network drives differently
  if [ "$DEVICE_TYPE" == "Network" ]; then
    echo "Mounting network drive: $DEVICE_PATH at $MOUNT_POINT..." | tee -a "$LOG_FILE"
    sudo mount -t cifs "$DEVICE_PATH" "$MOUNT_POINT" -o username=<username>,password=<password>,rw || \
    { echo "Failed to mount $DEVICE_PATH. Please check the network settings and try again." | tee -a "$LOG_FILE"; exit 1; }
    echo "Network drive mounted successfully at $MOUNT_POINT." | tee -a "$LOG_FILE"
  else
    # Handle USB and HDD drives
    echo "Mounting $DEVICE_TYPE device: $DEVICE_PATH at $MOUNT_POINT..." | tee -a "$LOG_FILE"
    sudo mount "$DEVICE_PATH" "$MOUNT_POINT" && \
    echo "$DEVICE_TYPE device mounted successfully at $MOUNT_POINT." | tee -a "$LOG_FILE" || \
    { echo "Failed to mount $DEVICE_PATH. Please check the device and try again." | tee -a "$LOG_FILE"; exit 1; }
  fi
done

# Notify user of successful connection
echo "All devices have been processed." | tee -a "$LOG_FILE"
