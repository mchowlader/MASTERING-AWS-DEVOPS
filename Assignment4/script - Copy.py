"""An AWS Python Pulumi program"""

import pulumi
import pulumi_aws as aws

#Create a VPC
vpc = aws.ec2.Vpc("my-vpc",
    cidr_block="10.0.0.0/16",
    tags={
        "Name":"my-vpc"
    }
)
pulumi.export("vpc_id",vpc.id)


#Create a public subnet
public_subnet=aws.ec2.Subnet("public-subnet",
    vpc_id=vpc.id,
    cidr_block="10.0.1.0/24",
    availability_zone="ap-southeast-1a",
    map_public_ip_on_launch=True,
    tags={
        "Name":"my-public-subnet"
    }
)
pulumi.export("public_subnet",public_subnet.id)

#Create a private subnet
private_subnet=aws.ec2.Subnet("private-subnet",
    vpc_id=vpc.id,
    cidr_block="10.0.2.0/24",
    availability_zone="ap-southeast-1a",
    tags={
        "Name":"my-private-subnet"
    }
)
pulumi.export("private_subnet",private_subnet.id)

#Create an internet gateway
igw = aws.ec2.InternetGateway("internet-gateway",
    vpc_id=vpc.id,
    tags={
        "Name": "my-internet-gateway"
    }
)
pulumi.export("igw_id", igw.id)

#Create a route table for the public subnet 
public_route_table=aws.ec2.RouteTable("public-route-table",
    vpc_id=vpc.id,
    tags={
        "Name":"my-public-route-table"
    }
)

#Create a route in the route table for the Internet Gateway
route = aws.ec2.Route("igw-route",
    route_table_id=public_route_table.id,
    destination_cidr_block="0.0.0.0/0",
    gateway_id=igw.id
)

#Associated the route table with the public subnet
route_table_association=aws.ec2.RouteTableAssociation("public-route-table-association",
    subnet_id=public_subnet.id,
    route_table_id=public_route_table.id
)
pulumi.export("public_route_table_id", public_route_table.id)


# Allocate an Elastic IP for the NAT Gateway
eip = aws.ec2.Eip("nat-eip")

# Create the NAT Gateway
nat_gateway = aws.ec2.NatGateway("nat-gateway",
    subnet_id=public_subnet.id,
    allocation_id=eip.id,
    tags={
        "Name": "my-nat-gateway"
    }
)
pulumi.export("nat_gateway_id", nat_gateway.id)

# Create a route table for the private subnet
private_route_table = aws.ec2.RouteTable("private-route-table",
    vpc_id=vpc.id,
    tags={
        "Name": "my-private-route-table"
    }
)

# Create a route in the route table for the NAT Gateway
private_route = aws.ec2.Route("nat-route",
    route_table_id=private_route_table.id,
    destination_cidr_block="0.0.0.0/0",
    nat_gateway_id=nat_gateway.id
)

# Associate the route table with the private subnet
private_route_table_association = aws.ec2.RouteTableAssociation("private-route-table-association",
    subnet_id=private_subnet.id,
    route_table_id=private_route_table.id
)
pulumi.export("private_route_table_id", private_route_table.id)


# Create a security group for the public instance
public_security_group = aws.ec2.SecurityGroup("public-secgrp",
    vpc_id=vpc.id,
    description='Enable HTTP and SSH access for public instance',
    ingress=[
        {'protocol': 'tcp', 'from_port': 80, 'to_port': 80, 'cidr_blocks': ['0.0.0.0/0']},
        {'protocol': 'tcp', 'from_port': 22, 'to_port': 22, 'cidr_blocks': ['0.0.0.0/0']}
    ],
    egress=[
        {'protocol': '-1', 'from_port': 0, 'to_port': 0, 'cidr_blocks': ['0.0.0.0/0']}
    ]
)

ami_id = "ami-0ae452be23f2d0353"  # Ubuntu 22.04 LTS latest as of now

# Create an EC2 instance in the public subnet
public_instance = aws.ec2.Instance("public-instance",
    instance_type="t2.micro",
    vpc_security_group_ids=[public_security_group.id],
    ami=ami_id,
    subnet_id=public_subnet.id,
    key_name="MyKeyPair",
    associate_public_ip_address=True,
    tags= {
    "Name":  "public-ec2"
    }
)

pulumi.export("public_instance_id", public_instance.id)
pulumi.export("public_instance_ip", public_instance.public_ip)


# Create a security group for the private instance
private_security_group = aws.ec2.SecurityGroup("private-secgrp",
    vpc_id=vpc.id,
    description='Enable SSH access for private instance',
    ingress=[
        {'protocol': 'tcp', 'from_port': 22, 'to_port': 22, 'cidr_blocks': ['0.0.0.0/0']}
    ],
    egress=[
        {'protocol': '-1', 'from_port': 0, 'to_port': 0, 'cidr_blocks': ['0.0.0.0/0']}
    ]
)

# Create an EC2 instance in the private subnet
private_instance = aws.ec2.Instance("private-instance",
    instance_type="t2.micro",
    vpc_security_group_ids=[private_security_group.id],
    ami=ami_id,
    subnet_id=private_subnet.id,
    key_name="MyKeyPair",
    tags= {
    "Name":  "private-ec2"
    }
)

pulumi.export("private_instance_id", private_instance.id)
pulumi.export("private_instance_ip", private_instance.private_ip)














#!/bin/bash

set -e

KEY="MyKeyPair.pem"
LOG_FILE="ec2_mysql_setup.log"

# Step 1: Assume Pulumi has already been run manually
echo "===== Reading Pulumi outputs =====" | tee -a "$LOG_FILE"
pulumi stack output --json > outputs.json

# Step 2: Extract IPs from JSON
PUBLIC_IP=$(jq -r '.public_instance_ip' outputs.json)
PRIVATE_IP=$(jq -r '.private_instance_ip' outputs.json)

echo "Public EC2 IP: $PUBLIC_IP" | tee -a "$LOG_FILE"
echo "Private EC2 IP: $PRIVATE_IP" | tee -a "$LOG_FILE"

# Step 3: Ensure local key permissions
chmod 400 "$KEY"

# Step 4: Copy key to public EC2 using scp
echo "===== Copying key to public EC2 =====" | tee -a "$LOG_FILE"
scp -i "$KEY" "$KEY" ubuntu@$PUBLIC_IP:~/MyKeyPair.pem | tee -a "$LOG_FILE"
ssh -i "$KEY" ubuntu@$PUBLIC_IP "chmod 400 ~/MyKeyPair.pem" | tee -a "$LOG_FILE"

# Step 5: SSH into public EC2 and then private EC2 to install MySQL
ssh -o StrictHostKeyChecking=no -i "$KEY" ubuntu@$PUBLIC_IP bash -s <<ENDSSH
set -e

echo "===== Connecting to private EC2 to install MySQL ====="
ssh -o StrictHostKeyChecking=no -i ~/MyKeyPair.pem ubuntu@$PRIVATE_IP bash -s <<ENDPRIVATE
set -e

echo "===== Updating system packages ====="
sudo apt update -y
sudo apt upgrade -y

echo "===== Installing MySQL server ====="
sudo apt-get install mysql-server -y

echo "===== Checking MySQL version ====="
mysql --version

echo "===== Running MySQL secure installation non-interactively ====="
sudo mysql --execute="ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'RootPassword123'; DELETE FROM mysql.user WHERE User=''; DROP DATABASE IF EXISTS test; FLUSH PRIVILEGES;"

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
sudo systemctl daemon-reload
sudo systemctl start mysql
sudo systemctl enable mysql
sudo systemctl status mysql
ENDPRIVATE

echo "===== Private EC2 MySQL setup completed ====="
ENDSSH

echo "===== All steps completed successfully. Logs are in $LOG_FILE ====="
