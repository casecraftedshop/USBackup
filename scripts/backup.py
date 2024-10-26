import os
import tarfile
import asyncio
from datetime import datetime
import asyncssh
import json
import logging
from concurrent.futures import ThreadPoolExecutor
from tenacity import retry, stop_after_attempt, wait_fixed
from tqdm import tqdm
import gnupg

# Load configuration from backup_config.json
with open('config/backup_config.json') as config_file:
    config = json.load(config_file)

local_backup_dir = config['local_backup_directory']
remote_backup_dir = config['remote_backup_directory']
ssh_host = os.getenv('SSH_HOST', config['ssh_host'])
ssh_user = os.getenv('SSH_USER', config['ssh_user'])
ssh_key_path = os.getenv('SSH_KEY_PATH', config['ssh_key_path'])
data_to_backup = config['data_to_backup']

# Create a timestamp for the backup file
timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')

# Configure logging
logging.basicConfig(filename='logs/backup_log.txt', level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# GPG Configuration
gpg = gnupg.GPG(gnupghome='/path/to/gnupg')


def create_backup(source_path):
    """Function to create a backup for a given source path with progress feedback."""
    backup_filename = f'backup_{os.path.basename(source_path)}_{timestamp}.tar.gz'
    backup_path = os.path.join(local_backup_dir, backup_filename)
    try:
        with tarfile.open(backup_path, 'w:gz') as tar:
            # Get total size of data to be backed up
            total_size = sum(os.path.getsize(os.path.join(root, file)) for root, _, files in os.walk(source_path) for file in files)
            with tqdm(total=total_size, unit='B', unit_scale=True, desc=f'Creating {backup_filename}') as pbar:
                for root, _, files in os.walk(source_path):
                    for file in files:
                        file_path = os.path.join(root, file)
                        tar.add(file_path, arcname=os.path.relpath(file_path, source_path))
                        pbar.update(os.path.getsize(file_path))
        logging.info(f'Backup {backup_filename} created successfully.')

        # Encrypt backup file
        with open(backup_path, 'rb') as f:
            encrypted_backup_path = f"{backup_path}.gpg"
            gpg.encrypt_file(
                f,
                recipients=None,
                symmetric=True,
                passphrase=os.getenv('BACKUP_ENCRYPTION_PASSPHRASE'),
                output=encrypted_backup_path
            )
        os.remove(backup_path)  # Remove unencrypted backup file
        logging.info(f'Backup {backup_filename} encrypted successfully.')
        return encrypted_backup_path
    except Exception as e:
        logging.error(f'Error creating or encrypting backup for {source_path}: {e}')
        raise


@retry(stop=stop_after_attempt(3), wait=wait_fixed(5))
async def upload_backup(backup_path):
    """Asynchronous function to upload the backup via SFTP with retry logic."""
    try:
        async with asyncssh.connect(ssh_host, username=ssh_user, client_keys=[ssh_key_path]) as conn:
            async with conn.start_sftp_client() as sftp:
                progress_bar = tqdm(total=os.path.getsize(backup_path), unit='B', unit_scale=True, desc=f'Uploading {os.path.basename(backup_path)}')
                async with sftp.open(os.path.join(remote_backup_dir, os.path.basename(backup_path)), 'w') as remote_file:
                    with open(backup_path, 'rb') as local_file:
                        while True:
                            data = local_file.read(1024)
                            if not data:
                                break
                            await remote_file.write(data)
                            progress_bar.update(len(data))
                progress_bar.close()
        logging.info(f'Backup {os.path.basename(backup_path)} uploaded successfully.')
    except Exception as e:
        logging.error(f'Error uploading backup {os.path.basename(backup_path)}: {e}')
        raise


async def main():
    try:
        # Create ThreadPoolExecutor for concurrent backup creation
        with ThreadPoolExecutor() as executor:
            loop = asyncio.get_event_loop()
            # Create backups concurrently
            backup_paths = await asyncio.gather(*[
                loop.run_in_executor(executor, create_backup, path) for path in data_to_backup
            ])

        # Upload backups concurrently
        await asyncio.gather(*[upload_backup(backup_path) for backup_path in backup_paths])
    except Exception as e:
        logging.error(f'Backup process failed: {e}')


if __name__ == '__main__':
    asyncio.run(main())
