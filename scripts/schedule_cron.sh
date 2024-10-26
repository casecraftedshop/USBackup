#!/bin/bash

# Configuration file for scheduling
BACKUP_CONFIG_FILE="backup_config.json"

# Load schedule details
BACKUP_INTERVAL=$(jq -r '.backup_interval' "$BACKUP_CONFIG_FILE")

# Check if the crontab is already set
CRON_JOB_EXISTS=$(crontab -l | grep "backup.sh")

# Schedule the backup script if it doesn't already exist
if [ -z "$CRON_JOB_EXISTS" ]; then
    echo "Scheduling backup script to run every $BACKUP_INTERVAL."
    (crontab -l; echo "$BACKUP_INTERVAL /path/to/backup.sh") | crontab -
    echo "Backup scheduled successfully."
else
    echo "Cron job for backup already exists."
fi
