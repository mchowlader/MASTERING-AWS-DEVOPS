#!/bin/bash

# Exit script on any error and catch errors in piped commands
#set -e
#set -o pipefail

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
chmod +x script/GetServerIP.sh script/UpdateMySQLSystemdIP.sh script/server.js nodejs/check-mysql.sh db/create-databse-and-user.sh

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
UPDATE=$("$SCRIPT_DIR/script/UpdateMySQLSystemdIP.sh") || {
    echo "[ERROR] Failed to update MySQL bind-address. Exiting..."
    exit 1
}
echo "[RESPONSE] $UPDATE"

# Move necessary scripts and service files
sudo mkdir -p /usr/local/bin
sudo mv -f nodejs/check-mysql.sh /usr/local/bin/check-mysql.sh
sudo mv -f db/mysql-check.service /etc/systemd/system/mysql-check.service

# Create databases and users
echo "[INFO] Creating databases and users..."
DATABSE_CREATE=$("$SCRIPT_DIR/db/create-databse-and-user.sh") || {
    echo "[ERROR] Failed to create database and user. Exiting..."
    exit 1
}
echo "[RESPONSE] $DATABSE_CREATE"

sleep 5
# Create application directory
sudo mkdir -p /opt/app

# Check if user 'nodejs' exists; if not, create it
if ! id -u nodejs > /dev/null 2>&1; then
    sudo useradd -r -s /bin/false nodejs
fi
sudo chown nodejs:nodejs /opt/app

#cd /opt/app

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "[INFO] Installing Node.js..."
    sudo apt update
    sudo apt install nodejs npm -y
else
    echo "[INFO] Node.js is already installed. Skipping installation."
fi

#start

# Check if nvm is installed and source it if it exists
if [ -s "$HOME/.nvm/nvm.sh" ]; then
    export NVM_DIR="$HOME/.nvm"
    . "$NVM_DIR/nvm.sh"
fi

# Dynamically find the path of npm
NPM_PATH=$(which npm)

# Output the npm path for debugging
echo "NPM_PATH: $NPM_PATH"

# Check if npm is installed
if [ -z "$NPM_PATH" ]; then
    echo "[ERROR] npm is not installed. Please install Node.js and npm first."
    exit 1
fi

echo "[INFO] Using npm from: $NPM_PATH"

# Check if npm packages are installed
if [ ! -d "node_modules" ]; then
    echo "[INFO] Initializing npm project..."
    sudo "$NPM_PATH" install --prefix /opt/app
    sudo -E "$NPM_PATH" install express mysql2 --prefix /opt/app
else
    echo "[INFO] npm packages already installed. Skipping installation."
fi

#end

sudo chown -R nodejs:nodejs /opt/app

echo "Move Node.js service file and update server.js"
sudo mv -f "$SCRIPT_DIR/nodejs/nodejs-app.service" /etc/systemd/system/nodejs-app.service
sudo mv -f  "$SCRIPT_DIR/script/server.js" /opt/app/server.js

# Update Node.js server IP in server.js
sed -i "s|^const SERVER_IP = .*;|const SERVER_IP = \"$SERVER_IP\";|" /opt/app/server.js


echo "Start and enable Node.js service"
if ! systemctl is-active --quiet nodejs-app; then
    echo "[INFO] Starting Node.js service..."
    sudo systemctl start nodejs-app
fi

sudo systemctl enable nodejs-app
sudo systemctl status nodejs-app

echo "[INFO] Script execution completed successfully."