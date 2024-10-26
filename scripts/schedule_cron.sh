#!/bin/bash

# Load configuration details
CONFIG_FILE="config/backup_config.json"
BACKUP_INTERVAL=$(jq -r '.backup_interval' "$CONFIG_FILE")

# Schedule the cron job if it doesn't already exist
CRON_JOB="0 $BACKUP_INTERVAL * * * /home/ubuntu/networked-backup-system/scripts/backup.sh"
(crontab -l | grep -q "$CRON_JOB") || (crontab -l; echo "$CRON_JOB") | crontab -

echo "Cron job for backup scheduled successfully."
