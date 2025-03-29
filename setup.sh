#!/bin/bash

# Exit on error
set -e

# Prompt the user for the server's IP address
exec 3<&0  # Save stdin to file descriptor 3
exec 0</dev/tty  # Redirect stdin to the terminal
read -p "Enter your server's IP address: " SERVER_IP
exec 0<&3  # Restore original stdin

# Validate the IP address format
if [[ ! $SERVER_IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "Invalid IP address. Exiting..."
    exit 1
fi

# Update and install dependencies
echo "Updating system and installing dependencies..."
sudo apt update -y
sudo apt install -y python3 python3-pip git sqlite3

# Install Python dependencies
echo "Installing Python dependencies..."
pip3 install flask flask-talisman gunicorn python-dotenv

# Remove old repository if it exists
if [ -d "/home/ubuntu/Usage" ]; then
    echo "Removing old repository..."
    sudo rm -rf /home/ubuntu/Usage
fi

# Clone the repository
echo "Cloning the repository..."
sudo git clone https://github.com/Tyga-x/Usage.git /home/ubuntu/Usage

# Create .env file with database path
echo "Setting up environment variables..."
DB_PATH="/etc/x-ui/x-ui.db"
if [ ! -f "/home/ubuntu/Usage/.env" ]; then
    echo "DB_PATH=$DB_PATH" | sudo tee /home/ubuntu/Usage/.env > /dev/null
else
    echo ".env file already exists. Skipping..."
fi

# Set up systemd service
echo "Configuring systemd service..."
SERVICE_FILE="/etc/systemd/system/usage-monitor.service"
if [ ! -f "$SERVICE_FILE" ]; then
    cat <<EOF | sudo tee $SERVICE_FILE > /dev/null
[Unit]
Description=Usage Monitor Service
After=network.target

[Service]
User=root
WorkingDirectory=/home/ubuntu/Usage
ExecStart=/usr/local/bin/gunicorn --workers 3 --bind 0.0.0.0:5000 app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable usage-monitor
    sudo systemctl start usage-monitor
else
    echo "Systemd service already configured. Restarting service..."
    sudo systemctl restart usage-monitor
fi

# Open port 5000 in the firewall
echo "Opening port 5000 in the firewall..."
sudo ufw allow 5000

# Print success message with the provided IP address
echo "Installation complete! Access the web interface at http://${SERVER_IP}:5000"

# Automatically open the web interface (optional)
echo "Opening the web interface in your browser..."
xdg-open "http://${SERVER_IP}:5000" || true
