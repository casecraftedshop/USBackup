import os
import tarfile
from datetime import datetime
import paramiko
import json
import logging

# Setup logging
logging.basicConfig(filename='backup_log.txt', level=logging.INFO,
                    format='%(asctime)s %(levelname)s: %(message)s')

# Load configuration
with open('config/backup_config.json', 'r') as config_file:
    config = json.load(config_file)

local_backup_dir = config['backup_directory']
remote_backup_dir = config['remote_directory']
ssh_host = config['ssh_host']
ssh_user = config['ssh_user']
ssh_key_path = config['ssh_key_path']
data_to_backup = config['data_to_backup']

# Create a timestamp for the backup file
timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
backup_filename = f'backup_{timestamp}.tar.gz'

# Function to create a backup
def create_backup():
    try:
        backup_path = os.path.join(local_backup_dir, backup_filename)
        with tarfile.open(backup_path, 'w:gz') as tar:
            tar.add(data_to_backup, arcname=os.path.basename(data_to_backup))
        logging.info(f"Backup created successfully: {backup_path}")
    except Exception as e:
        logging.error(f"Failed to create backup: {e}")
        raise

# Function to upload the backup to remote server
def upload_backup():
    try:
        transport = paramiko.Transport((ssh_host, 22))
        transport.connect(username=ssh_user, key_filename=ssh_key_path)
        sftp = paramiko.SFTPClient.from_transport(transport)

        try:
            local_path = os.path.join(local_backup_dir, backup_filename)
            remote_path = os.path.join(remote_backup_dir, backup_filename)
            sftp.put(local_path, remote_path)
            logging.info(f"Backup uploaded successfully to {ssh_host}:{remote_path}")
        finally:
            sftp.close()
            transport.close()
    except Exception as e:
        logging.error(f"Failed to upload backup: {e}")
        raise

if __name__ == '__main__':
    try:
        create_backup()
        upload_backup()
        logging.info("Backup process completed successfully.")
    except Exception as e:
        logging.error(f"Backup process failed: {e}")
