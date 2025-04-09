#!/bin/bash

set -e

echo "Detecting server's public IP address..."
PUBLIC_IP=$(curl -s http://ipinfo.io/ip)
echo "Detected server IP: $PUBLIC_IP"

echo "Stopping and removing old installation..."
sudo systemctl stop usage-monitor || true
sudo systemctl disable usage-monitor || true
sudo rm -f /etc/systemd/system/usage-monitor.service

echo "Updating system and installing dependencies..."
sudo apt update
sudo apt install -y python3 python3-venv python3-pip git curl sqlite3

echo "Creating a Python virtual environment..."
python3 -m venv usage-venv
source usage-venv/bin/activate

echo "Upgrading pip..."
pip install --upgrade pip

echo "Installing Python dependencies..."
pip install flask flask-talisman gunicorn python-dotenv pytz

echo "Cloning the repository..."
git clone https://github.com/Tyga-x/Usage.git /home/ubuntu/Usage

echo "Setting up environment variables..."
echo "DB_PATH=/etc/x-ui/x-ui.db" > /home/ubuntu/Usage/.env

echo "Configuring systemd service..."
sudo tee /etc/systemd/system/usage-monitor.service > /dev/null <<EOF
[Unit]
Description=Usage Monitor Service
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/Usage
ExecStart=/home/ubuntu/usage-venv/bin/gunicorn --workers 4 --bind 0.0.0.0:9000 app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "Enabling and starting the service..."
sudo systemctl enable usage-monitor
sudo systemctl start usage-monitor

echo "Installation complete!"
echo "Access the web interface at http://$PUBLIC_IP:9000"
echo "To check the status of the service, run: sudo systemctl status usage-monitor"
echo "To view logs, run: sudo journalctl -u usage-monitor -b"
