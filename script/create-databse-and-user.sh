#!/bin/bash

DB_NAME="practice_app"
DB_USER="app_user"
DB_PASS="app_user"

echo "Creating MySQL database and user..."

sudo mysql -e "
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
"

echo "Database and user setup complete."

# Insert data into table after database creation
sudo mysql -D $DB_NAME -e "
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL
);

INSERT INTO users (name, email) VALUES 
('Alice Johnson', 'alice@example.com'),
('Bob Smith', 'bob@example.com'),
('Charlie Brown', 'charlie@example.com');
"

echo "Users table created and sample data inserted."

# Restart MySQL service
sudo systemctl restart mysql
sudo systemctl status mysql --no-pager

echo "MySQL restarted successfully."
