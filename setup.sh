#!/bin/bash

# Exit on error
set -e

# Update and install dependencies
echo "Updating system and installing dependencies..."
sudo apt update -y
sudo apt install -y python3 python3-pip git nginx sqlite3

# Install Python dependencies
echo "Installing Python dependencies..."
pip3 install flask flask-talisman gunicorn python-dotenv

# Clone the repository
echo "Cloning the repository..."
if [ ! -d "/opt/Usage" ]; then
    sudo git clone https://github.com/Tyga-x/Usage.git /opt/Usage
else
    echo "Repository already cloned. Pulling latest changes..."
    cd /opt/Usage && sudo git pull origin main
fi

# Create .env file with database path
echo "Setting up environment variables..."
DB_PATH="/etc/x-ui/x-ui.db"
if [ ! -f "/opt/Usage/.env" ]; then
    echo "DB_PATH=$DB_PATH" | sudo tee /opt/Usage/.env > /dev/null
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
WorkingDirectory=/opt/Usage
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

# Configure Nginx for HTTP
echo "Configuring Nginx..."
NGINX_CONF="/etc/nginx/sites-available/usage-monitor"
if [ ! -f "$NGINX_CONF" ]; then
    cat <<EOF | sudo tee $NGINX_CONF > /dev/null
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF
    sudo ln -sf /etc/nginx/sites-available/usage-monitor /etc/nginx/sites-enabled/
    sudo systemctl restart nginx
else
    echo "Nginx configuration already exists. Reloading Nginx..."
    sudo systemctl reload nginx
fi

echo "Installation complete! Access the web interface at http://<your-vps-ip>"
