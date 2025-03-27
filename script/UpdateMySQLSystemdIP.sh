#!/bin/bash

echo "Hello"
# Get the current working directory dynamically
SCRIPT_DIR=$(pwd)
SERVER_IP=$($SCRIPT_DIR/GetServerIP.sh)
echo "SERVER_IP: $SERVER_IP"  # Debugging line
CONFIG_FILE="/etc/mysql/mysql.conf.d/mysqld.cnf"
MYSQL_SERVICE=$(/usr/local/bin/check-mysql.sh)
echo "MYSQL_SERVICE: $MYSQL_SERVICE"  # Debugging line

echo "Updating MySQL bind-address to : $SERVER_IP"

sed -i "s/^bind-address\s*=.*/bind-address=$SERVER_IP/" "$CONFIG_FILE"
sed -i "s/^DB_HOST\s*=.*/DB_HOST=$SERVER_IP/" "$MYSQL_SERVICE"

sudo systemctl restart mysql

# Check MySQL status
MYSQL_STATUS=$(systemctl is-active mysql)

# Print success message based on status
if [ "$MYSQL_STATUS" == "active" ]; then
    echo "Update successful! MySQL is running."
else
    echo "Update failed! MySQL is not running."
fi