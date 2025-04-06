#!/bin/bash

# Exit on error
set -e

# Redirect stdin to the terminal for interactive input
exec 3<&0  # Save original stdin
exec 0</dev/tty  # Redirect stdin to the terminal

# Prompt the user for the server's IP address
read -p "Enter your server's IP address: " SERVER_IP

# Validate the IP address format
if [[ ! $SERVER_IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "Invalid IP address. Exiting..."
    exit 1
fi

# Restore original stdin
exec 0<&3

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

# Kill any processes using port 5000
echo "Checking for processes using port 5000..."
PID=$(sudo lsof -t -i :5000 || true)
if [ ! -z "$PID" ]; then
    echo "Killing process(es) using port 5000: $PID"
    sudo kill -9 $PID || true
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
pip install flask flask-talisman gunicorn python-dotenv

# Deactivate the virtual environment (it will be reactivated by the systemd service)
deactivate

# Clone the repository
echo "Cloning the repository..."
sudo git clone https://github.com/Tyga-x/Usage.git /home/ubuntu/Usage

# Create .env file with database path
echo "Setting up environment variables..."
DB_PATH="/etc/x-ui/x-ui.db"  # Ensure this matches your actual database path
if [ ! -f "/home/ubuntu/Usage/.env" ]; then
    echo "DB_PATH=$DB_PATH" | sudo tee /home/ubuntu/Usage/.env > /dev/null
else
    echo ".env file already exists. Skipping..."
fi

# Set up systemd service
echo "Configuring systemd service..."
SERVICE_FILE="/etc/systemd/system/usage-monitor.service"
cat <<EOF | sudo tee $SERVICE_FILE > /dev/null
[Unit]
Description=Usage Monitor Service
After=network.target

[Service]
User=root
WorkingDirectory=/home/ubuntu/Usage
ExecStart=$VENV_PATH/bin/gunicorn --workers 3 --bind 0.0.0.0:5000 app:app
Restart=always
Environment="DB_PATH=$DB_PATH"

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start the service
sudo systemctl daemon-reload
sudo systemctl enable usage-monitor
sudo systemctl start usage-monitor

# Verify the application is listening on port 5000
echo "Verifying port 5000..."
LISTENING=$(sudo netstat -tuln | grep 5000)
if [[ -z "$LISTENING" ]]; then
    echo "WARNING: The application is not listening on port 5000. Check logs for errors."
else
    echo "Application is listening on port 5000."
fi

# Print success message with the provided IP address
echo "Installation complete! Access the web interface at http://${SERVER_IP}:5000"
