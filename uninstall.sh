#!/bin/bash

# Exit on error
set -e

# Stop and remove the systemd service
echo "Stopping and removing usage-monitor service..."
if systemctl is-active --quiet usage-monitor; then
    sudo systemctl stop usage-monitor || true
fi

if [ -f "/etc/systemd/system/usage-monitor.service" ]; then
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

# Remove the repository and virtual environment
if [ -d "/home/ubuntu/Usage" ]; then
    echo "Removing repository..."
    sudo rm -rf /home/ubuntu/Usage
fi

if [ -d "/home/ubuntu/usage-venv" ]; then
    echo "Removing virtual environment..."
    sudo rm -rf /home/ubuntu/usage-venv
fi

# Remove the database file (optional, uncomment if needed)
# echo "Removing database file..."
# sudo rm -f /etc/x-ui/x-ui.db

# Final cleanup message
echo "Uninstallation complete!"
echo "All files and services related to the Usage Monitor have been removed."
