# Step 1: Set Up the Environment with Linux Mint 22
# 1.1 Download Linux Mint 22 ISO
wget -O linuxmint-22.iso https://linuxmint.com/download.php

# 1.2 Use Ventoy to create multiboot USB
sudo apt install -y ventoy
ventoy -i /dev/sdX  # Replace sdX with your USB drive identifier
cp linuxmint-22.iso /mnt/ventoy

# Step 2: Boot and Configure Linux Mint
# Boot from USB and select Linux Mint 22 with persistence

# 2.1 Install dependencies for USBackup project
sudo apt update
sudo apt install -y nginx git python3 python3-pip mongodb jq fail2ban openssh-server ufw curl net-tools

# Step 3: Set Up the Environment for USBackup Project
# 3.1 Create a directory to store USBackup project files
mkdir -p ~/USBackup

# 3.2 Clone the USBackup repository into the created directory
git clone https://github.com/casecraftedshop/USBackup.git ~/USBackup

# 3.3 Install Python dependencies
cd ~/USBackup
pip3 install -r requirements.txt

# Step 4: Set Up Nginx for USBackup
# 4.1 Configure Nginx to serve USBackup
sudo tee /etc/nginx/sites-available/usbackup > /dev/null <<EOL
server {
    listen 80;
    server_name localhost;

    root /home/yourusername/USBackup/ui;
    index index.html index.htm;

    location / {
        try_files $uri $uri/ =404;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:5000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOL

# Enable the Nginx configuration and restart the service
sudo ln -s /etc/nginx/sites-available/usbackup /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx

# Step 5: Configure Automatic Project Execution
# 5.1 Create startup script for USBackup
cat <<EOL > ~/USBackup/startup.sh
#!/bin/bash

# Load environment variables from GitHub Secrets
BACKUP_ENCRYPTION_PASSPHRASE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/repos/casecraftedshop/USBackup/actions/secrets/BACKUP_ENCRYPTION_PASSPHRASE | jq -r .value)
SSID=$(curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/repos/casecraftedshop/USBackup/actions/secrets/SSID | jq -r .value)
WIFI_PASSWORD=$(curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/repos/casecraftedshop/USBackup/actions/secrets/WIFI_PASSWORD | jq -r .value)

if [ -z "$BACKUP_ENCRYPTION_PASSPHRASE" ] || [ -z "$SSID" ] || [ -z "$WIFI_PASSWORD" ]; then
    echo "Failed to load secrets from GitHub. Aborting." | tee -a "~/USBackup/logs/backup_log.txt"
    exit 1
fi

# Update from GitHub repository
cd ~/USBackup || exit
git pull origin main

# Start MongoDB service
sudo systemctl start mongodb

# Start Python Flask app (assuming it is used for the backend API)
nohup python3 ~/USBackup/scripts/backup.py &> ~/USBackup/logs/backup.log &

# Restart Nginx to ensure it's running
sudo systemctl restart nginx

# Start Flask server for notifications
nohup python3 ~/USBackup/scripts/flask_server.py &> ~/USBackup/logs/flask_server.log &

echo "USBackup project started successfully"
EOL

# Make the script executable
chmod +x ~/USBackup/startup.sh

# 5.2 Set up systemd service for automatic execution
sudo tee /etc/systemd/system/usbackup.service > /dev/null <<EOL
[Unit]
Description=USBackup Project Service
After=network.target

[Service]
ExecStart=/home/yourusername/USBackup/startup.sh
Restart=always
RestartSec=10
User=yourusername
WorkingDirectory=/home/yourusername/USBackup
EnvironmentFile=/home/yourusername/USBackup/.env
ProtectSystem=full
ProtectHome=true
PrivateTmp=true
NoNewPrivileges=true
LimitNOFILE=4096
TimeoutStartSec=30

[Install]
WantedBy=multi-user.target
EOL

# Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable usbackup.service
sudo systemctl start usbackup.service

# Step 6: Ensure Connectivity, Power Management, and Recovery
# 6.1 Set up persistent Wi-Fi
nmcli device wifi connect "$SSID" password "$WIFI_PASSWORD" ifname wlan0
nmcli connection modify "$SSID" connection.autoconnect yes

# 6.2 Enable Wake on Power in BIOS/UEFI settings
# Manually enable "Wake on Power" in BIOS

# 6.3 Self-healing and connectivity cronjobs
(crontab -l 2>/dev/null; echo "0 4 * * * /sbin/shutdown -r now") | crontab -
(crontab -l 2>/dev/null; echo "*/5 * * * * nmcli networking connectivity check || nmcli device wifi connect \"$SSID\" password \"$WIFI_PASSWORD\"") | crontab -

# Step 7: Backup and Remote Access
# 7.1 Automated rsync backup
mkdir -p ~/USBackup/encrypted_backup
(crontab -l 2>/dev/null; echo "0 3 * * * rsync -av --delete ~/USBackup ~/USBackup/encrypted_backup/ --exclude-from='~/USBackup/.backup_exclude' --log-file='~/USBackup/logs/rsync_backup.log'") | crontab -

# 7.2 Enable remote access via SSH
sudo systemctl enable ssh
sudo systemctl start ssh

# Set up No-IP for dynamic DNS
sudo apt install -y noip2
sudo noip2 -C

# Step 8: Logging and Monitoring
# 8.1 Centralized logging
mkdir -p ~/USBackup/logs

# 8.2 Install Netdata for monitoring
bash <(curl -Ss https://my-netdata.io/kickstart.sh)

# Step 9: Security Enhancements and Backup Verification
# 9.1 Encrypt backup using GPG
BACKUP_FILE=~/USBackup/encrypted_backup/backup_$(date +%Y%m%d_%H%M%S).tar.gz
tar -czf $BACKUP_FILE ~/USBackup --exclude='~/USBackup/encrypted_backup/*' --exclude='~/USBackup/logs/*'
gpg --batch --yes --passphrase "$BACKUP_ENCRYPTION_PASSPHRASE" -c $BACKUP_FILE
rm $BACKUP_FILE

# 9.2 Verify backup integrity
ENCRYPTED_BACKUP_FILE=${BACKUP_FILE}.gpg
gpg --batch --yes --passphrase "$BACKUP_ENCRYPTION_PASSPHRASE" -d $ENCRYPTED_BACKUP_FILE > ~/USBackup/encrypted_backup/backup_decrypted.tar.gz
if ! cmp --silent ~/USBackup/encrypted_backup/backup_decrypted.tar.gz ~/USBackup/encrypted_backup/backup_$(date +%Y%m%d_%H%M%S).tar.gz; then
    echo "Backup verification failed." | tee -a ~/USBackup/logs/backup_log.txt
else
    rm ~/USBackup/encrypted_backup/backup_decrypted.tar.gz
fi

# 9.3 Set up monitoring with fail2ban for SSH protection
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# 9.4 Enable UFW Firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

# Step 10: Flask Server Integration for Notification and Device Mounting
# 10.1 Flask Server Integration - Notify remote backup location access using email accounts
nohup python3 ~/USBackup/scripts/flask_server.py &> ~/USBackup/logs/flask_server.log &

# Step 11: Check Project File Structure and Configuration
# 11.1 Verify and set up required directories
REQUIRED_DIRS=("~/USBackup/logs" "~/USBackup/ui" "~/USBackup/scripts" "~/USBackup/encrypted_backup")
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
    fi
done

# 11.2 Ensure all scripts are executable
find ~/USBackup/scripts -type f -name "*.sh" -exec chmod +x {} \;
find ~/USBackup/scripts -type f -name "*.py" -exec chmod +x {} \;

# 11.3 Validate .env file
if [ ! -f "~/USBackup/.env" ]; then
    echo "Missing .env file. Please create one with the necessary configurations." | tee -a ~/USBackup/logs/backup_log.txt
    exit 1
fi

# 11.4 Confirm MongoDB is configured properly
if ! pgrep -x "mongod" > /dev/null; then
    echo "MongoDB is not running. Please check the MongoDB setup." | tee -a ~/USBackup/logs/backup_log.txt
    exit 1
fi
