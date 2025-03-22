#!/bin/bash

sudo chmod +x db/GetServerIP.sh
sudo chmod +x db/check-mysql.sh.sh
sudo chmod +x db/create-databse-and-user.sh

#Install MySQL
sudo apt-get update
sudo apt-get install mysql-server -y

#Configure MySQL to allow remote connections
#Updating MySQL bind-address to: $SERVER_IP
bash "$script/UpdateMySQLSystemdIP.sh"

mv mysql-check.service  /etc/systemd/system/mysql-check.service

sudo systemctl daemon-reload
sudo systemctl start mysql-check