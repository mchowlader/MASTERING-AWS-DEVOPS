#!/bin/bash

#STEP-1:
set -e  # Exit script on any error
set -o pipefail  # Catch errors in piped commands

LOG_FILE="install.log"
exec > >(tee -a "$LOG_FILE") 2>&1  # Log output to file

echo "[INFO] Granting execute permissions to required scripts..."
sudo chmod +x script/GetServerIP.sh
sudo chmod +x nodejs/check-mysql.sh
sudo chmod +x db/create-databse-and-user.sh
sudo chmod +x script/UpdateMySQLSystemdIP.sh

#STEP-2:

# Get the current working directory dynamically
SCRIPT_DIR=$(pwd)

# First, retrieve the server IP
echo "[INFO] Retrieving server IP..."
SERVER_IP=($SCRIPT_DIR/script/GetServerIP.sh) || {
    echo "[ERROR] Failed to retrieve server IP. Exiting..."
    exit 1
}
echo "[INFO] Server IP: $SERVER_IP"
echo "$SCRIPT_DIR"
# Then, update MySQL bind-address
echo "[INFO] Updating MySQL bind-address to: $SERVER_IP"
Success=($SCRIPT_DIR/script/UpdateMySQLSystemdIP.sh "$SERVER_IP") || {
    echo "[ERROR] Failed to update MySQL bind-address. Exiting..."
    exit 1
}

echo "[INFO] Creating script directory if not exists..."
sudo mkdir -p /usr/local/bin

echo "[INFO] Moving MySQL check script to /usr/local/bin..."
sudo mv -f nodejs/check-mysql.sh /usr/local/bin/check-mysql.sh

echo "[INFO] Moving MySQL systemd service file to /etc/systemd/system/..."
sudo mv -f db/mysql-check.service /etc/systemd/system/mysql-check.service

#STEP-3:
#sudo apt-get update
#sudo apt-get install mysql-server

# Reload systemd to recognize the new service
sudo systemctl daemon-reload

echo "[INFO] Starting mysql-check service..."
sudo systemctl start mysql 
sleep 5;

sudo systemctl enable mysql


# Then, update MySQL bind-address
echo "[INFO] Creating Databases and Users.."
success2=($SCRIPT_DIR/db/create-databse-and-user.sh) || {
    echo "[ERROR] Failed to create-databse-and-user..."
    exit 1
}

#STEP-4:

echo "[INFO] Script execution completed successfully."