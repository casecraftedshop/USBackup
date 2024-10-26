#!/bin/bash

# Load configuration details from JSON files
CONFIG_FILE="config/backup_config.json"
BACKUP_DIR=$(jq -r '.backup_directory' "$CONFIG_FILE")
SOURCE_PATH=$(jq -r '.source_path' "$CONFIG_FILE")
LOG_FILE="logs/backup_log.txt"

# Check if backup directory exists; create if not
if [ ! -d "$BACKUP_DIR" ]; then
    echo "Creating backup directory $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
fi

# Create a backup
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/backup_$TIMESTAMP.tar.gz"
echo "Creating backup: $BACKUP_FILE"
tar -czf "$BACKUP_FILE" "$SOURCE_PATH"

# Log the backup
echo "Backup completed at $(date) - $BACKUP_FILE" >> "$LOG_FILE"

# Notify user
echo "Backup completed successfully!"
