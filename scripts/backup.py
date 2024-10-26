import os
import tarfile
import asyncio
from datetime import datetime
import paramiko
import json

# Load configuration from backup_config.json
with open('config/backup_config.json') as config_file:
    config = json.load(config_file)

local_backup_dir = config['local_backup_directory']
remote_backup_dir = config['remote_backup_directory']
ssh_host = config['ssh_host']
ssh_user = config['ssh_user']
ssh_key_path = config['ssh_key_path']
data_to_backup = config['data_to_backup']

# Create a timestamp for the backup file
timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
backup_filename = f'backup_{timestamp}.tar.gz'

async def create_backup():
    """Asynchronous function to create a backup."""
    backup_path = os.path.join(local_backup_dir, backup_filename)
    try:
        with tarfile.open(backup_path, 'w:gz') as tar:
            for path in data_to_backup:
                tar.add(path, arcname=os.path.basename(path))
        print(f'Backup {backup_filename} created successfully.')
    except Exception as e:
        print(f'Error creating backup: {e}')

async def upload_backup():
    """Asynchronous function to upload the backup via SFTP."""
    backup_path = os.path.join(local_backup_dir, backup_filename)
    transport = paramiko.Transport((ssh_host, 22))
    try:
        transport.connect(username=ssh_user, key_filename=ssh_key_path)
        sftp = paramiko.SFTPClient.from_transport(transport)
        sftp.put(backup_path, os.path.join(remote_backup_dir, backup_filename))
        print(f'Backup {backup_filename} uploaded successfully.')
    except Exception as e:
        print(f'Error uploading backup: {e}')
    finally:
        sftp.close()
        transport.close()

async def main():
    await create_backup()
    await upload_backup()

if __name__ == '__main__':
    asyncio.run(main())
