#!/bin/bash

SERVER_IP=$(bash ./GetServerIP.sh)
CONFIG_FILE="/etc/mysql/mysql.conf.d/mysqld.cnf"

echo "Updating MySQL bind-address to : $SERVER_IP"

sed -i "s/^bind-address\s*=.*/bind-address=$SERVER_IP/" "$CONFIG_FILE"

sudo systemctl restart mysql

# Check MySQL status
MYSQL_STATUS=$(systemctl is-active mysql)

# Print success message based on status
if [ "$MYSQL_STATUS" == "active" ]; then
    echo "Update successful! MySQL is running."
else
    echo "Update failed! MySQL is not running."
fi