from flask import Flask, jsonify, request
import subprocess
import os
import json

app = Flask(__name__)

@app.route('/api/run-backup', methods=['POST'])
def run_backup():
    try:
        # Execute the shell script to initiate backup
        subprocess.Popen(['./scripts/backup.sh'])
        return jsonify({'message': 'Backup started successfully.'}), 200
    except Exception as e:
        return jsonify({'message': f'Failed to start backup: {str(e)}'}), 500

@app.route('/api/backup-status', methods=['GET'])
def backup_status():
    try:
        # Mock status check - In production, this should retrieve real-time status
        status_message = "All systems are operational!"
        return jsonify({'status': status_message}), 200
    except Exception as e:
        return jsonify({'message': f'Failed to retrieve status: {str(e)}'}), 500

@app.route('/api/mount-device', methods=['POST'])
def mount_device():
    try:
        data = request.get_json()
        device_path = data['device_path']
        mount_point = data['mount_point']
        subprocess.run(['sudo', 'mount', device_path, mount_point], check=True)
        return jsonify({'message': f'Device {device_path} mounted successfully at {mount_point}.'}), 200
    except Exception as e:
        return jsonify({'message': f'Failed to mount device: {str(e)}'}), 500

@app.route('/api/unmount-device', methods=['POST'])
def unmount_device():
    try:
        data = request.get_json()
        mount_point = data['mount_point']
        subprocess.run(['sudo', 'umount', mount_point], check=True)
        return jsonify({'message': f'Device at {mount_point} unmounted successfully.'}), 200
    except Exception as e:
        return jsonify({'message': f'Failed to unmount device: {str(e)}'}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
