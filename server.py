from flask import Flask, jsonify, request, render_template, abort
import subprocess
import os
import logging
from flask_cors import CORS
from dotenv import load_dotenv
from logging.handlers import RotatingFileHandler
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

app = Flask(__name__)
CORS(app, resources={r"/api/*": {"origins": "https://yourfrontenddomain.com"}})  # Enable CORS for a specific domain

# Load environment variables from .env file
load_dotenv()

# Configure logging with rotation to avoid overly large log files
handler = RotatingFileHandler('logs/server_log.txt', maxBytes=5000000, backupCount=5)
logging.basicConfig(handlers=[handler], level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Set up rate limiter
limiter = Limiter(get_remote_address, app=app, default_limits=["200 per day", "50 per hour"])

# Authorization Token from Environment
AUTH_TOKEN = os.getenv('AUTH_TOKEN')

# Function to verify token
def verify_token(token):
    if token and token.startswith("Bearer "):
        return token.split(" ")[1] == AUTH_TOKEN
    return False

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
@limiter.limit("10 per minute")
def run_backup():
    token = request.headers.get('Authorization')
    if not verify_token(token):
        abort(401, 'Unauthorized')

    try:
        # Execute the shell script to initiate backup
        subprocess.Popen(['sudo', './scripts/backup.sh'])
        logging.info('Backup process started successfully.')
        return jsonify({'message': 'Backup started successfully.'}), 200
    except Exception as e:
        logging.error(f"Failed to start backup: {str(e)}")
        return jsonify({'message': 'Failed to start backup, please contact system administrator.'}), 500

# Route to get the backup status
@app.route('/api/backup-status', methods=['GET'])
@limiter.limit("10 per minute")
def backup_status():
    token = request.headers.get('Authorization')
    if not verify_token(token):
        abort(401, 'Unauthorized')

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
@limiter.limit("5 per minute")
def mount_device():
    token = request.headers.get('Authorization')
    if not verify_token(token):
        abort(401, 'Unauthorized')

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
@limiter.limit("5 per minute")
def unmount_device():
    token = request.headers.get('Authorization')
    if not verify_token(token):
        abort(401, 'Unauthorized')

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
    # Example command to run with Gunicorn:
    # gunicorn -w 4 -b 0.0.0.0:5000 server:app
    app.run(host='0.0.0.0', port=5000)
