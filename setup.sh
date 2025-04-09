#!/bin/bash

# Exit on error
set -e

# Detect the server's public IP address automatically
echo "Detecting server's public IP address..."
SERVER_IP=$(curl -s https://api.ipify.org || dig +short myip.opendns.com @resolver1.opendns.com || hostname -I | awk '{print $1}')
if [[ -z "$SERVER_IP" || ! $SERVER_IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "Failed to detect the server's public IP address. Exiting..."
    exit 1
fi
echo "Detected server IP: $SERVER_IP"

# Stop and remove old installation if it exists
echo "Stopping and removing old installation..."

# Stop the systemd service if it exists
if systemctl is-active --quiet usage-monitor; then
    echo "Stopping existing usage-monitor service..."
    sudo systemctl stop usage-monitor || true
fi

# Disable the systemd service if it exists
if [ -f "/etc/systemd/system/usage-monitor.service" ]; then
    echo "Disabling existing usage-monitor service..."
    sudo systemctl disable usage-monitor || true
    sudo rm -f /etc/systemd/system/usage-monitor.service
fi

# Kill any processes using port 9000
echo "Checking for processes using port 9000..."
PID=$(sudo lsof -t -i :9000 || true)
if [ ! -z "$PID" ]; then
    echo "Process(es) using port 9000: $PID"
    read -p "Kill these processes? (y/n): " KILL_CONFIRM
    if [[ $KILL_CONFIRM == "y" || $KILL_CONFIRM == "Y" ]]; then
        sudo kill -9 $PID || true
        echo "Processes killed."
    else
        echo "Exiting due to port conflict. Please free port 9000 manually."
        exit 1
    fi
fi

# Remove old repository and virtual environment
if [ -d "/home/ubuntu/Usage" ]; then
    echo "Removing old repository..."
    sudo rm -rf /home/ubuntu/Usage
fi

if [ -d "/home/ubuntu/usage-venv" ]; then
    echo "Removing old virtual environment..."
    sudo rm -rf /home/ubuntu/usage-venv
fi

# Change to a safe working directory
cd /home/ubuntu

# Update and install dependencies
echo "Updating system and installing dependencies..."
sudo apt update -y
sudo apt install -y python3 python3-venv git sqlite3 curl

# Create a virtual environment in /home/ubuntu
echo "Creating a Python virtual environment..."
VENV_PATH="/home/ubuntu/usage-venv"
python3 -m venv $VENV_PATH

# Activate the virtual environment
source $VENV_PATH/bin/activate

# Upgrade pip in the virtual environment
pip install --upgrade pip

# Install Python dependencies in the virtual environment
echo "Installing Python dependencies..."
pip install flask flask-talisman gunicorn python-dotenv pytz

# Deactivate the virtual environment (it will be reactivated by the systemd service)
deactivate

# Clone the repository
echo "Cloning the repository..."
sudo git clone https://github.com/Tyga-x/Usage.git /home/ubuntu/Usage

# Set ownership of the repository and virtual environment to root
sudo chown -R root:root $VENV_PATH /home/ubuntu/Usage

# Validate database path
DB_PATH="/etc/x-ui/x-ui.db"  # Ensure this matches your actual database path
if [ ! -f "$DB_PATH" ]; then
    echo "Database file not found at $DB_PATH. Exiting..."
    exit 1
fi

# Create .env file with database path
echo "Setting up environment variables..."
if [ ! -f "/home/ubuntu/Usage/.env" ]; then
    echo "DB_PATH=$DB_PATH" | sudo tee /home/ubuntu/Usage/.env > /dev/null
else
    echo ".env file already exists. Skipping..."
fi

# Set up systemd service
echo "Configuring systemd service..."
SERVICE_FILE="/etc/systemd/system/usage-monitor.service"
WORKERS=$(nproc)  # Dynamically calculate workers based on CPU cores
cat <<EOF | sudo tee $SERVICE_FILE > /dev/null
[Unit]
Description=Usage Monitor Service
After=network.target

[Service]
User=root
WorkingDirectory=/home/ubuntu/Usage
ExecStart=$VENV_PATH/bin/gunicorn --workers $WORKERS --bind 0.0.0.0:9000 app:app
Restart=always
Environment="DB_PATH=$DB_PATH"

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start the service
sudo systemctl daemon-reload
sudo systemctl enable usage-monitor
sudo systemctl start usage-monitor

# Final success message
echo "Installation complete!"
echo "Access the web interface at http://${SERVER_IP}:9000"
echo "To check the status of the service, run: sudo systemctl status usage-monitor"
echo "To view logs, run: sudo journalctl -u usage-monitor -b"

# Wait for user input before exiting
read -p "Press Enter to exit..."
