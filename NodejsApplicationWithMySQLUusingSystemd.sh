#!/bin/bash

sudo chmod +x ./script/GetServerIP.sh
sudo chmod +x ./script/check-mysql.sh.sh
sudo chmod +x ./script/create-databse-and-user.sh

sudo mkdir -p db
sudo mkdir -p nodejs

mv ./script/check-mysql.sh ./db
mv ./script/create-databse-and-user.sh ./db

#Install MySQL
sudo apt-get update
sudo apt-get install mysql-server -y

#Configure MySQL to allow remote connections
#Updating MySQL bind-address to: $SERVER_IP
bash "$script/UpdateMySQLSystemdIP.sh"

mv mysql-check.service  /etc/systemd/system/mysql-check.service

sudo systemctl daemon-reload
sudo systemctl start mysql-check