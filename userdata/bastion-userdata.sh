#!/bin/bash
# Bastion Host Setup Script for Amazon Linux 2

# Update system
yum update -y

# Install useful tools for administration
yum install -y wget curl nano vim htop mysql

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Install Session Manager plugin
yum install -y https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm

# Configure SSH banner
cat > /etc/ssh/ssh_banner << 'EOF'
################################################################################
#                                                                              #
#  This is a BASTION HOST for secure access to private resources.             #
#  All activities are logged and monitored.                                   #
#  Unauthorized access is strictly prohibited.                                #
#                                                                              #
################################################################################
EOF

# Update SSH configuration
echo "Banner /etc/ssh/ssh_banner" >> /etc/ssh/sshd_config
systemctl restart sshd

# Create a helpful script for connecting to private instances
cat > /home/ec2-user/connect-to-web.sh << 'EOF'
#!/bin/bash
echo "Available web servers:"
aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=*wordpress*" "Name=instance-state-name,Values=running" \
    --query 'Reservations[*].Instances[*].[InstanceId,PrivateIpAddress,Tags[?Key==`Name`].Value|[0]]' \
    --output table

echo "To connect to a web server, use:"
echo "ssh -i YOUR_KEY.pem ec2-user@PRIVATE_IP"
EOF

chmod +x /home/ec2-user/connect-to-web.sh
chown ec2-user:ec2-user /home/ec2-user/connect-to-web.sh

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Set up log forwarding for SSH access
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/secure",
                        "log_group_name": "/aws/ec2/bastion/secure",
                        "log_stream_name": "{instance_id}"
                    }
                ]
            }
        }
    }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# Log completion
echo "Bastion host setup completed at $(date)" >> /var/log/bastion-setup.log

# Create motd
cat > /etc/motd << 'EOF'

    ____  ___   _____ ______   ____  _   __
   / __ )/   | / ___// ____/  / __ \/ | / /
  / __  / /| | \__ \/ __/    / / / /  |/ / 
 / /_/ / ___ |___/ / /___   / /_/ / /|  /  
/_____/_/  |_/____/_____/   \____/_/ |_/   
                                           
Welcome to the Bastion Host!
Use ./connect-to-web.sh to see available web servers.

EOF
