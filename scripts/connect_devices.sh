{
  "devices": [
    {
      "device_type": "USB",
      "device_path": "${USB_DEVICE_PATH}",
      "mount_point": "/mnt/usb",
      "filesystem_type": "ext4",
      "capacity": "64G",
      "vendor": "Kingston",
      "product": "DataTraveler 3.0",
      "serial_number": "${USB_SERIAL_NUMBER}",
      "is_enabled": true,
      "encryption": "aes256",
      "health_check": true,
      "logging_level": "ERROR",
      "notification_enabled": true
    },
    {
      "device_type": "HDD",
      "device_path": "${HDD_DEVICE_PATH}",
      "mount_point": "/mnt/hdd",
      "filesystem_type": "ext4",
      "capacity": "1TB",
      "vendor": "Seagate",
      "product": "Backup Plus",
      "serial_number": "${HDD_SERIAL_NUMBER}",
      "is_enabled": true,
      "encryption": "aes256",
      "health_check": true,
      "logging_level": "ERROR",
      "notification_enabled": true
    },
    {
      "device_type": "Network",
      "device_path": "${NETWORK_DEVICE_PATH}",
      "mount_point": "/mnt/network_drive",
      "filesystem_type": "cifs",
      "capacity": "500GB",
      "vendor": "Synology",
      "product": "NAS",
      "serial_number": "${NETWORK_SERIAL_NUMBER}",
      "network_username": "${NETWORK_USERNAME}",
      "network_password": "${NETWORK_PASSWORD}",
      "is_enabled": true,
      "encryption": "aes256",
      "health_check": true,
      "logging_level": "ERROR",
      "notification_enabled": true
    }
  ],
  "notification_email": "${NOTIFICATION_EMAIL}",
  "backup_directory": "${BACKUP_DIRECTORY}",
  "backup_interval": "${BACKUP_INTERVAL}"
}
