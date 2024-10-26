#!/bin/bash

# Configuration file for scheduling
BACKUP_CONFIG_FILE="config/backup_config.json"
BACKUP_SCRIPT_PATH="$(pwd)/scripts/backup.sh"

# Check for dependencies
command -v jq >/dev/null 2>&1 || { echo >&2 "jq is not installed. Aborting."; exit 1; }

# Load schedule details
BACKUP_INTERVAL=$(jq -r '.backup_interval' "$BACKUP_CONFIG_FILE")

# Validate configuration
if [ -z "$BACKUP_INTERVAL" ]; then
    echo "Error: Backup interval not specified in configuration file."
    exit 1
fi

# Check if the crontab is already set for this backup script
CRON_JOB_EXISTS=$(crontab -l 2>/dev/null | grep "$BACKUP_SCRIPT_PATH")

# Schedule the backup script if it doesn't already exist
if [ -z "$CRON_JOB_EXISTS" ]; then
    echo "Scheduling backup script to run every $BACKUP_INTERVAL."
    (crontab -l 2>/dev/null; echo "$BACKUP_INTERVAL $BACKUP_SCRIPT_PATH") | crontab -
    echo "Backup scheduled successfully."
else
    echo "Cron job for backup already exists."
fi

# Notify user
crontab -l | grep "$BACKUP_SCRIPT_PATH" && echo "Cron job is active." || echo "Failed to schedule the cron job."
