#!/bin/bash

chmod +x script/GetServerIP.sh
chmod +x nodejs/check-mysql.sh
chmod +x db/create-databse-and-user.sh
chmod +x script/UpdateMySQLSystemdIP.sh

#Install MySQL
sudo apt-get update
sudo apt-get install mysql-server -y

#Configure MySQL to allow remote connections
#Updating MySQL bind-address to: $SERVER_IP
sudo ./script/UpdateMySQLSystemdIP.sh

# Create script directory
mkdir -p /usr/local/bin
sudo mv nodejs/check-mysql.sh  /usr/local/bin/check-mysql.sh

sudo mv db/mysql-check.service  /etc/systemd/system/mysql-check.service

sudo systemctl daemon-reload
sudo systemctl start mysql-check