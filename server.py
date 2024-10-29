from flask import Flask, jsonify, request, render_template
import subprocess
import os
import json
import logging
from flask_cors import CORS
from dotenv import load_dotenv
from functools import wraps
import secrets

app = Flask(__name__)
CORS(app)  # Enable CORS for the API

# Load environment variables from .env file
load_dotenv()

# Security: Authentication token (should be stored in an environment variable)
API_TOKEN = os.getenv('API_TOKEN', 'default_token')

# Configure logging
logging.basicConfig(filename='logs/server_log.txt', level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Authentication decorator
def require_auth(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('Authorization')
        if not token or token != f"Bearer {API_TOKEN}":
            logging.warning('Unauthorized access attempt.')
            return jsonify({'message': 'Unauthorized'}), 401
        return f(*args, **kwargs)
    return decorated

# Base route to serve index.html for root URL requests
@app.route('/')
def home():
    try:
        return render_template('index.html')
    except Exception as e:
        logging.error(f"Error loading the home page: {str(e)}")
        return f"Error loading the home page: {str(e)}", 500

# Route to run the backup process
@app.route('/api/run-backup', methods=['POST'])
@require_auth
def run_backup():
    try:
        # Execute the shell script to initiate backup
        subprocess.Popen(['./scripts/backup.sh'])
        logging.info('Backup process started successfully.')
        return jsonify({'message': 'Backup started successfully.'}), 200
    except Exception as e:
        logging.error(f"Failed to start backup: {str(e)}")
        return jsonify({'message': 'Failed to start backup, please contact system administrator.'}), 500

# Route to get the backup status
@app.route('/api/backup-status', methods=['GET'])
@require_auth
def backup_status():
    try:
        # Mock status check - In production, this should retrieve real-time status
        status_message = "All systems are operational!"
        logging.info('Backup status retrieved successfully.')
        return jsonify({'status': status_message}), 200
    except Exception as e:
        logging.error(f"Failed to retrieve status: {str(e)}")
        return jsonify({'message': 'Failed to retrieve status, please contact system administrator.'}), 500

# Route to mount a USB or external drive
@app.route('/api/mount-device', methods=['POST'])
@require_auth
def mount_device():
    try:
        data = request.get_json()
        device_path = data.get('device_path')
        mount_point = data.get('mount_point')

        if not device_path or not mount_point:
            raise ValueError("Device path or mount point is missing.")

        # Run the mount command
        subprocess.run(['sudo', 'mount', device_path, mount_point], check=True)
        logging.info(f"Device {device_path} mounted successfully at {mount_point}.")
        return jsonify({'message': f'Device {device_path} mounted successfully at {mount_point}.'}), 200
    except subprocess.CalledProcessError as e:
        logging.error(f"Failed to mount device: {str(e)}")
        return jsonify({'message': 'Failed to mount device, please contact system administrator.'}), 500
    except ValueError as ve:
        logging.error(f"Error: {str(ve)}")
        return jsonify({'message': f'Error: {str(ve)}'}), 400
    except Exception as e:
        logging.error(f"Failed to mount device: {str(e)}")
        return jsonify({'message': 'Failed to mount device, please contact system administrator.'}), 500

# Route to unmount a USB or external drive
@app.route('/api/unmount-device', methods=['POST'])
@require_auth
def unmount_device():
    try:
        data = request.get_json()
        mount_point = data.get('mount_point')

        if not mount_point:
            raise ValueError("Mount point is missing.")

        # Run the unmount command
        subprocess.run(['sudo', 'umount', mount_point], check=True)
        logging.info(f"Device at {mount_point} unmounted successfully.")
        return jsonify({'message': f'Device at {mount_point} unmounted successfully.'}), 200
    except subprocess.CalledProcessError as e:
        logging.error(f"Failed to unmount device: {str(e)}")
        return jsonify({'message': 'Failed to unmount device, please contact system administrator.'}), 500
    except ValueError as ve:
        logging.error(f"Error: {str(ve)}")
        return jsonify({'message': f'Error: {str(ve)}'}), 400
    except Exception as e:
        logging.error(f"Failed to unmount device: {str(e)}")
        return jsonify({'message': 'Failed to unmount device, please contact system administrator.'}), 500

# Health check route
@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'Server is up and running!'}), 200

if __name__ == '__main__':
    # For production, use a WSGI server like Gunicorn
    app.run(host='0.0.0.0', port=5000)
