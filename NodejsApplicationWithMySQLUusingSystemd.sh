#!/bin/bash

# Exit script on any error and catch errors in piped commands
set -e
set -o pipefail

LOG_FILE="install.log"
exec > >(tee -a "$LOG_FILE") 2>&1  # Log output to file

# Update package list
sudo apt-get update
sleep 5

# Check if MySQL is already installed
if ! command -v mysql &> /dev/null; then
    echo "[INFO] Installing MySQL..."
    sudo apt-get install -y mysql-server
    sudo systemctl daemon-reload
else
    echo "[INFO] MySQL is already installed. Skipping installation."
fi

# Start and enable MySQL service
if ! systemctl is-active --quiet mysql; then
    echo "[INFO] Starting MySQL service..."
    sudo systemctl start mysql
fi

sudo systemctl enable mysql

# Grant execute permissions to required scripts
chmod +x script/GetServerIP.sh script/UpdateMySQLSystemdIP.sh nodejs/check-mysql.sh db/create-databse-and-user.sh

# Get the current working directory dynamically
SCRIPT_DIR=$(pwd)

# Retrieve the server IP
echo "[INFO] Retrieving server IP..."
SERVER_IP=$("$SCRIPT_DIR/script/GetServerIP.sh") || {
    echo "[ERROR] Failed to retrieve server IP. Exiting..."
    exit 1
}
echo "[INFO] Server IP: $SERVER_IP"

# Update MySQL bind-address
echo "[INFO] Updating MySQL bind-address to: $SERVER_IP"
Success=$("$SCRIPT_DIR/script/UpdateMySQLSystemdIP.sh") || {
    echo "[ERROR] Failed to update MySQL bind-address. Exiting..."
    exit 1
}

# Move necessary scripts and service files
sudo mkdir -p /usr/local/bin
sudo mv -f nodejs/check-mysql.sh /usr/local/bin/check-mysql.sh
sudo mv -f db/mysql-check.service /etc/systemd/system/mysql-check.service

# Create databases and users
echo "[INFO] Creating databases and users..."
success2=$("$SCRIPT_DIR/db/create-databse-and-user.sh") || {
    echo "[ERROR] Failed to create database and user. Exiting..."
    exit 1
}

# Create application directory
sudo mkdir -p /opt/app

# Check if user 'nodejs' exists; if not, create it
if ! id -u nodejs > /dev/null 2>&1; then
    sudo useradd -r -s /bin/false nodejs
fi
sudo chown nodejs:nodejs /opt/app

cd /opt/app

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "[INFO] Installing Node.js..."
    sudo apt update
    sudo apt install nodejs npm -y
else
    echo "[INFO] Node.js is already installed. Skipping installation."
fi

# Check if npm packages are installed
if [ ! -d "node_modules" ]; then
    echo "[INFO] Initializing npm project..."
    sudo npm init -y
    sudo npm install express mysql2
else
    echo "[INFO] npm packages already installed. Skipping installation."
fi

sudo chown -R nodejs:nodejs /opt/app

# Move Node.js service file and update server.js
#sudo mv -f ./nodejs/nodejs-app.service /etc/systemd/system/nodejs-app.service
sudo mv -f "$SCRIPT_DIR/nodejs/nodejs-app.service" /etc/systemd/system/nodejs-app.service
sudo mv -f ./script/server.js /opt/app/server.js

# Update Node.js server IP in server.js
sed -i "s|^const SERVER_IP = .*;|const SERVER_IP = \"$SERVER_IP\";|" /opt/app/server.js


# Start and enable Node.js service
if ! systemctl is-active --quiet nodejs-app; then
    echo "[INFO] Starting Node.js service..."
    sudo systemctl start nodejs-app
fi

sudo systemctl enable nodejs-app
sudo systemctl status nodejs-app

echo "[INFO] Script execution completed successfully."