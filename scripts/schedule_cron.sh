#!/bin/bash

# Load environment variables
if [ -f ".env" ]; then
    source .env
else
    echo ".env file not found. Aborting." | tee -a "logs/cron_schedule_log.txt"
    exit 1
fi

# Configuration file for scheduling
BACKUP_CONFIG_FILE="$(pwd)/config/backup_config.json"
BACKUP_SCRIPT_PATH="$(pwd)/scripts/backup.sh"
LOG_DIR="$(pwd)/logs"
LOG_FILE="${LOG_DIR}/cron_schedule_log.txt"

# Ensure jq is installed
command -v jq >/dev/null 2>&1 || { echo "jq is not installed. Aborting." | tee -a "$LOG_FILE"; exit 1; }

# Create log directory if it doesn't exist
if [ ! -d "$LOG_DIR" ]; then
    echo "Log directory does not exist. Creating $LOG_DIR." | tee -a "$LOG_FILE"
    mkdir -p "$LOG_DIR" || { echo "Failed to create log directory $LOG_DIR. Aborting." | tee -a "$LOG_FILE"; exit 1; }
fi

# Load schedule details from backup config
BACKUP_INTERVAL=$(jq -r '.backup_interval' "$BACKUP_CONFIG_FILE")

# Validate configuration - Use default interval if not specified
if [ -z "$BACKUP_INTERVAL" ] || [ "$BACKUP_INTERVAL" == "null" ]; then
    echo "Warning: Backup interval not specified. Defaulting to '@daily'." | tee -a "$LOG_FILE"
    BACKUP_INTERVAL="@daily"
fi

# Retry mechanism for crontab modification
RETRY_COUNT=3
for attempt in $(seq 1 $RETRY_COUNT); do
    # Check if the crontab is already set for this backup script
    CRON_JOB_EXISTS=$(crontab -l 2>/dev/null | grep -F "$BACKUP_SCRIPT_PATH")

    if [ -z "$CRON_JOB_EXISTS" ]; then
        echo "Attempt $attempt/$RETRY_COUNT: Scheduling backup script to run at interval $BACKUP_INTERVAL." | tee -a "$LOG_FILE"
        (crontab -l 2>/dev/null; echo "$BACKUP_INTERVAL $BACKUP_SCRIPT_PATH >> $LOG_FILE 2>&1") | crontab - || {
            echo "Failed to add cron job on attempt $attempt." | tee -a "$LOG_FILE"
            sleep 5
            continue
        }
    fi

    # Verify if cron job is active
    if crontab -l | grep -q -F "$BACKUP_SCRIPT_PATH"; then
        echo "Cron job is active and verified." | tee -a "$LOG_FILE"
        break
    elif [ "$attempt" -eq "$RETRY_COUNT" ]; then
        echo "Failed to schedule the cron job after $RETRY_COUNT attempts." | tee -a "$LOG_FILE"
        exit 1
    else
        echo "Retrying cron job scheduling..." | tee -a "$LOG_FILE"
        sleep 5
    fi
done

# Notify user of final status
crontab -l | grep -F "$BACKUP_SCRIPT_PATH" > /dev/null && \
    echo "Cron job is active." | tee -a "$LOG_FILE" || \
    { echo "Failed to schedule the cron job." | tee -a "$LOG_FILE"; exit 1; }
