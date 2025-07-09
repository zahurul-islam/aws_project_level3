#!/bin/bash
# WordPress Installation Script for Amazon Linux 2

# Update system
yum update -y

# Install required packages
yum install -y httpd php php-mysqlnd mysql wget

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Configure firewall (if running)
if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --reload
fi

# Install MySQL Server (only if RDS is not enabled)
%{ if !enable_rds }
yum install -y mysql-server
systemctl start mysqld
systemctl enable mysqld

# Set up MySQL root password and create WordPress database
mysql -e "CREATE DATABASE ${db_name};"
mysql -e "CREATE USER '${db_user}'@'localhost' IDENTIFIED BY '${db_password}';"
mysql -e "GRANT ALL PRIVILEGES ON ${db_name}.* TO '${db_user}'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"
%{ endif }

# Download and install WordPress
cd /tmp
wget https://wordpress.org/latest.tar.gz
tar xzf latest.tar.gz
cp -R wordpress/* /var/www/html/

# Set proper permissions
chown -R apache:apache /var/www/html/
chmod -R 755 /var/www/html/

# Create WordPress configuration
cd /var/www/html
cp wp-config-sample.php wp-config.php

# Configure WordPress database settings
sed -i "s/database_name_here/${db_name}/" wp-config.php
sed -i "s/username_here/${db_user}/" wp-config.php
sed -i "s/password_here/${db_password}/" wp-config.php
sed -i "s/localhost/${db_host}/" wp-config.php

# Generate WordPress salts
curl -s https://api.wordpress.org/secret-key/1.1/salt/ >> /tmp/wp-salts.txt
sed -i '/AUTH_KEY/,/NONCE_SALT/{
    r /tmp/wp-salts.txt
    d
}' wp-config.php

# Remove default Apache page
rm -f /var/www/html/index.html

# Restart Apache
systemctl restart httpd

# Install CloudWatch agent for monitoring
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Create a simple health check page
cat > /var/www/html/health.php << 'EOF'
<?php
http_response_code(200);
echo json_encode(['status' => 'healthy', 'timestamp' => date('c')]);
?>
EOF

# Log completion
echo "WordPress installation completed at $(date)" >> /var/log/wordpress-install.log
