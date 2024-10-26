#!/bin/bash

set -e  # Exit immediately if any command exits with a non-zero status
set -u  # Treat unset variables as an error
set -o pipefail  # Fail on first failure in a pipe

# Load environment variables
if [ -f ".env" ]; then
    source .env
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: .env file not found. Aborting." | tee -a "logs/connect_storage.log"
    exit 1
fi

# Configuration file for storage devices
STORAGE_DEVICES_FILE="config/storage_devices.json"
LOG_FILE="logs/connect_storage.log"
RETRY_COUNT=3
LOG_DIR="$(dirname "$LOG_FILE")"

# Create log directory if it doesn't exist
if [ ! -d "$LOG_DIR" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO: Log directory does not exist. Creating $LOG_DIR." | tee -a "$LOG_FILE"
    mkdir -p "$LOG_DIR" || { echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Failed to create log directory $LOG_DIR. Aborting." | tee -a "$LOG_FILE"; exit 1; }
fi

# Check for dependencies
command -v jq >/dev/null 2>&1 || { echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: jq is not installed. Aborting." | tee -a "$LOG_FILE"; exit 1; }

# Function to mount a device
mount_device() {
    local device_path=$1
    local mount_point=$2
    local device_type=$3

    # Retry mechanism for mounting
    for attempt in $(seq 1 $RETRY_COUNT); do
        if [ "$device_type" == "Network" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO: Attempt $attempt/$RETRY_COUNT: Mounting network drive: $device_path at $mount_point..." | tee -a "$LOG_FILE"
            sudo mount -t cifs "$device_path" "$mount_point" -o username="$NETWORK_USERNAME",password="$NETWORK_PASSWORD",rw && \
            echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO: Network drive mounted successfully at $mount_point." | tee -a "$LOG_FILE" && break || sleep $((5 * attempt))
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO: Attempt $attempt/$RETRY_COUNT: Mounting $device_type device: $device_path at $mount_point..." | tee -a "$LOG_FILE"
            sudo mount "$device_path" "$mount_point" && \
            echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO: $device_type device mounted successfully at $mount_point." | tee -a "$LOG_FILE" && break || sleep $((5 * attempt))
        fi

        # If the final attempt fails, log and move on to the next device
        if [ "$attempt" -eq "$RETRY_COUNT" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Failed to mount $device_path after $RETRY_COUNT attempts. Skipping device." | tee -a "$LOG_FILE"
        fi
    done
}

# Load device information
NUM_DEVICES=$(jq '.devices | length' "$STORAGE_DEVICES_FILE")

# Process each device in parallel where possible
for (( i=0; i<$NUM_DEVICES; i++ )); do
    IS_ENABLED=$(jq -r ".devices[$i].is_enabled" "$STORAGE_DEVICES_FILE")

    # Skip devices that are not enabled
    if [ "$IS_ENABLED" != "true" ]; then
        continue
    fi

    DEVICE_PATH=$(jq -r ".devices[$i].device_path" "$STORAGE_DEVICES_FILE")
    MOUNT_POINT=$(jq -r ".devices[$i].mount_point" "$STORAGE_DEVICES_FILE")
    DEVICE_TYPE=$(jq -r ".devices[$i].device_type" "$STORAGE_DEVICES_FILE")

    # Mask sensitive information for logs
    if [ "$DEVICE_TYPE" == "Network" ]; then
        MASKED_PATH=$(echo "$DEVICE_PATH" | sed 's/[^\/]*$/***/')
    else
        MASKED_PATH="$DEVICE_PATH"
    fi

    # Create mount point if it doesn't exist
    if [ ! -d "$MOUNT_POINT" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO: Mount point $MOUNT_POINT does not exist. Creating it." | tee -a "$LOG_FILE"
        mkdir -p "$MOUNT_POINT" || { echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Failed to create mount point $MOUNT_POINT. Skipping device." | tee -a "$LOG_FILE"; continue; }
    fi

    # Mount device in the background
    mount_device "$DEVICE_PATH" "$MOUNT_POINT" "$DEVICE_TYPE" &
done

# Wait for all background tasks to finish
wait

# Notify user of completion
echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO: All devices have been processed." | tee -a "$LOG_FILE"
