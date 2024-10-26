import os
import tarfile
from datetime import datetime
import paramiko

# Configuration
local_backup_dir = '/home/ubuntu/backups/'
remote_backup_dir = '/remote/backup/path'
ssh_host = '15.223.3.155'
ssh_user = 'ubuntu'
ssh_key_path = '/path/to/private/key'

# Create a timestamp for the backup file
timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
backup_filename = f'backup_{timestamp}.tar.gz'

def create_backup():
    with tarfile.open(os.path.join(local_backup_dir, backup_filename), 'w:gz') as tar:
        tar.add('/path/to/data/to/backup', arcname=os.path.basename('/path/to/data/to/backup'))

def upload_backup():
    transport = paramiko.Transport((ssh_host, 22))
    transport.connect(username=ssh_user, key_filename=ssh_key_path)
    sftp = paramiko.SFTPClient.from_transport(transport)

    try:
        sftp.put(os.path.join(local_backup_dir, backup_filename), os.path.join(remote_backup_dir, backup_filename))
    finally:
        sftp.close()
        transport.close()

if __name__ == '__main__':
    create_backup()
    upload_backup()
