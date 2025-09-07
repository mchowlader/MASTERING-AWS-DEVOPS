#!/bin/bash

set -e

KEY="MyKeyPair.pem"
LOG_FILE="ec2_mysql_setup.log"

# Step 1: Provision infra with Pulumi (non-interactive)
echo "===== Running Pulumi to provision infrastructure =====" | tee -a "$LOG_FILE"
pulumi up --yes &>> "$LOG_FILE"

# Step 2: Export stack outputs to JSON
echo "===== Exporting Pulumi outputs =====" | tee -a "$LOG_FILE"
pulumi stack output --json > outputs.json

# Step 3: Extract IPs from JSON
PUBLIC_IP=$(jq -r '.public_instance_ip' outputs.json)
PRIVATE_IP=$(jq -r '.private_instance_ip' outputs.json)

echo "Public EC2 IP: $PUBLIC_IP" | tee -a "$LOG_FILE"
echo "Private EC2 IP: $PRIVATE_IP" | tee -a "$LOG_FILE"

# Step 4: Ensure key permissions
chmod 400 "$KEY"

# Step 5: SSH into public EC2 and then private EC2 to install MySQL
ssh -o StrictHostKeyChecking=no -i "$KEY" ubuntu@$PUBLIC_IP bash -s <<ENDSSH
set -e

echo "===== Copying key to public EC2 ====="
cat > /home/ubuntu/MyKeyPair.pem <<'EOF_KEY'
$(cat "$KEY")
EOF_KEY
chmod 400 /home/ubuntu/MyKeyPair.pem
chown ubuntu:ubuntu /home/ubuntu/MyKeyPair.pem

echo "===== Connecting to private EC2 to install MySQL ====="
ssh -o StrictHostKeyChecking=no -i ~/MyKeyPair.pem ubuntu@$PRIVATE_IP bash -s <<ENDPRIVATE
set -e

LOG_FILE="ec2_mysql_setup.log"

echo "===== Updating system packages ====="
sudo apt update -y &>> \$LOG_FILE
sudo apt upgrade -y &>> \$LOG_FILE

echo "===== Installing MySQL server ====="
sudo apt-get install mysql-server -y &>> \$LOG_FILE

echo "===== Checking MySQL version ====="
mysql --version &>> \$LOG_FILE

echo "===== Running MySQL secure installation non-interactively ====="
sudo mysql --execute="ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'RootPassword123'; DELETE FROM mysql.user WHERE User=''; DROP DATABASE IF EXISTS test; FLUSH PRIVILEGES;" &>> \$LOG_FILE

echo "===== Creating MySQL systemd service file ====="
sudo tee /etc/systemd/system/mysql.service > /dev/null <<'EOF'
[Unit]
Description=MySQL Server
After=syslog.target
After=network.target

[Service]
Type=simple
PermissionsStartOnly=true
ExecStartPre=/bin/mkdir -p /var/run/mysqld
ExecStartPre=/bin/chown mysql:mysql -R /var/run/mysqld
ExecStart=/usr/sbin/mysqld --basedir=/usr --datadir=/var/lib/mysql --plugin-dir=/usr/lib/mysql/plugin --log-error=/var/log/mysql/error.log --pid-file=/var/run/mysqld/mysqld.pid --socket=/var/run/mysqld/mysqld.sock --port=3306
TimeoutSec=300
PrivateTmp=true
User=mysql
Group=mysql
WorkingDirectory=/usr

[Install]
WantedBy=multi-user.target
EOF

echo "===== Reloading systemd daemon and starting MySQL ====="
sudo systemctl daemon-reload &>> \$LOG_FILE
sudo systemctl start mysql &>> \$LOG_FILE
sudo systemctl enable mysql &>> \$LOG_FILE

# MySQL connectivity check
echo "===== Checking MySQL connectivity ====="
if sudo mysqladmin ping -h 127.0.0.1 -u root -pRootPassword123 &> /dev/null; then
    echo "MySQL is running and accepting connections."
else
    echo "MySQL is NOT responding!"
fi

ENDPRIVATE

echo "===== Private EC2 MySQL setup completed ====="
ENDSSH

echo "===== All steps completed successfully. Logs are in $LOG_FILE ====="
