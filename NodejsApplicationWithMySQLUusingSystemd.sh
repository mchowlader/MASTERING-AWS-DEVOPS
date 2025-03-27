#!/bin/bash

#sudo chmod +x script/GetServerIP.sh
#sudo chmod +x nodejs/check-mysql.sh
#sudo chmod +x db/create-databse-and-user.sh
#sudo chmod +x script/UpdateMySQLSystemdIP.sh

#Install MySQL
#sudo apt-get update
#sudo apt-get install mysql-server -y

#Configure MySQL to allow remote connections
#Updating MySQL bind-address to: $SERVER_IP
#sudo ./script/UpdateMySQLSystemdIP.sh

# Create script directory
#mkdir -p /usr/local/bin
#sudo mv nodejs/check-mysql.sh  /usr/local/bin/check-mysql.sh
#
#sudo mv db/mysql-check.service  /etc/systemd/system/mysql-check.service
#
#sudo systemctl daemon-reload
#sudo systemctl start mysql-check





set -e  # Exit script on any error
set -o pipefail  # Catch errors in piped commands

LOG_FILE="install.log"
exec > >(tee -a "$LOG_FILE") 2>&1  # Log output to file

echo "[INFO] Granting execute permissions to required scripts..."
sudo chmod +x script/GetServerIP.sh
sudo chmod +x nodejs/check-mysql.sh
sudo chmod +x db/create-databse-and-user.sh
sudo chmod +x script/UpdateMySQLSystemdIP.sh

echo "[INFO] Retrieving server IP..."
SERVER_IP= sudo script/GetServerIP.sh || {
    echo "[ERROR] Failed to retrieve server IP. Exiting..."
    exit 1
}
echo "[INFO] Server IP: $SERVER_IP"

# First, retrieve the server IP
echo "[INFO] Retrieving server IP..."
SERVER_IP=$(./script/GetServerIP.sh) || {
    echo "[ERROR] Failed to retrieve server IP. Exiting..."
    exit 1
}

# Then, update MySQL bind-address
echo "[INFO] Updating MySQL bind-address to: $SERVER_IP"
sudo $(./script/UpdateMySQLSystemdIP.sh) "$SERVER_IP" || {
    echo "[ERROR] Failed to update MySQL bind-address. Exiting..."
    exit 1
}

echo "[INFO] Creating script directory if not exists..."
sudo mkdir -p /usr/local/bin

echo "[INFO] Moving MySQL check script to /usr/local/bin..."
sudo mv -f nodejs/check-mysql.sh /usr/local/bin/check-mysql.sh

echo "[INFO] Moving MySQL systemd service file to /etc/systemd/system/..."
sudo mv -f db/mysql-check.service /etc/systemd/system/mysql-check.service

# Reload systemd to recognize the new service
sudo systemctl daemon-reload

echo "[INFO] Starting mysql-check service..."
sudo systemctl start mysql-check && sudo systemctl enable mysql-check

echo "[INFO] Script execution completed successfully."
