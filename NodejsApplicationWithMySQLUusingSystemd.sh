#!/bin/bash

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
