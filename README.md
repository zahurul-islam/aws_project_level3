# AWS Capstone Project Level 3 - Terraform Infrastructure

This Terraform project creates a comprehensive, scalable WordPress infrastructure on AWS using best practices for security, monitoring, and backup. The infrastructure is designed to be AWS Free Tier friendly while demonstrating enterprise-level architecture patterns.

## 🏗️ Architecture Overview

### Core Components
- **VPC**: Multi-AZ Virtual Private Cloud with public, private, and database subnets
- **Load Balancer**: Application Load Balancer for high availability
- **Auto Scaling**: Auto Scaling Group with CloudWatch-based scaling policies
- **Database**: RDS MySQL with automated backups and monitoring
- **Security**: Bastion host for secure access (optional)
- **Backup**: Automated backup solution using AWS Backup
- **Monitoring**: CloudWatch metrics and alarms

### Key Features
✅ **Multi-AZ Deployment**: Resources spread across multiple availability zones  
✅ **Auto Scaling**: Automatic scaling based on CPU utilization  
✅ **Load Balancing**: Application Load Balancer with health checks  
✅ **Secure Access**: Optional bastion host for secure SSH access  
✅ **Database**: RDS MySQL with automated backups  
✅ **Monitoring**: CloudWatch alarms and metrics  
✅ **Backup**: Automated daily and weekly backups  
✅ **Cost Optimized**: Free tier friendly with optional cost-incurring features  

## 📋 Prerequisites

1. **AWS Account**: Active AWS account with appropriate permissions
2. **Terraform**: Terraform >= 1.0 installed
3. **AWS CLI**: Configured with your credentials
4. **EC2 Key Pair**: Create an EC2 key pair in your target region

### AWS Permissions Required
Your AWS user/role needs permissions for:
- EC2 (instances, security groups, load balancers)
- VPC (subnets, route tables, gateways)
- RDS (database instances, subnet groups)
- IAM (roles, policies, instance profiles)
- CloudWatch (alarms, logs)
- AWS Backup (vaults, plans, selections)
- KMS (keys for encryption)

## 🚀 Quick Start

### 1. Clone and Configure

```bash
# Navigate to the project directory
cd /path/to/aws_project_level3

# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit the variables file with your specific values
nano terraform.tfvars
```

### 2. Update terraform.tfvars

**Required Changes:**
```hcl
# Replace with your actual EC2 key pair name
key_pair_name = "your-actual-key-pair-name"

# Change the database password
wordpress_db_password = "YourSecurePassword123!"

# Optional: Adjust other settings as needed
aws_region = "us-east-1"
project_name = "my-wordpress-project"
```

### 3. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply
```

### 4. Access WordPress

After deployment completes (5-10 minutes), you'll see output with the load balancer DNS name:

```bash
# Access WordPress in your browser
http://your-load-balancer-dns-name
```

## 💰 Cost Considerations

### Free Tier Resources
- **EC2**: t2.micro instances (750 hours/month free)
- **RDS**: db.t3.micro (750 hours/month free)
- **Load Balancer**: 750 hours/month free
- **Storage**: 30GB EBS, 20GB RDS storage free
- **Data Transfer**: 15GB/month free

### Optional Paid Resources
- **NAT Gateway**: ~$45/month (disabled by default)
- **Additional EBS storage**: $0.10/GB-month beyond free tier
- **Data transfer**: $0.09/GB beyond free tier

## 🔧 Configuration Options

### Feature Toggles

| Variable | Default | Description | Cost Impact |
|----------|---------|-------------|-------------|
| `enable_nat_gateway` | `false` | Enable NAT Gateway for private subnet internet access | 💰 High |
| `enable_bastion_host` | `true` | Deploy bastion host for secure access | ⭐ Free tier |
| `enable_rds` | `true` | Use RDS instead of local MySQL | ⭐ Free tier |

### Scaling Configuration

```hcl
# Auto Scaling settings
auto_scaling_min_size = 1          # Minimum instances
auto_scaling_max_size = 3          # Maximum instances  
auto_scaling_desired_capacity = 2  # Desired instances
```

### Security Configuration

```hcl
# Network settings
vpc_cidr = "10.0.0.0/16"
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
```

## 🔐 Security Features

### Network Security
- **Private Subnets**: Web servers in private subnets
- **Security Groups**: Principle of least privilege
- **Bastion Host**: Secure SSH access (optional)
- **Database Isolation**: RDS in dedicated database subnets

### Encryption
- **EBS Encryption**: All volumes encrypted at rest
- **RDS Encryption**: Database encrypted at rest
- **Backup Encryption**: KMS-encrypted backups

### Access Control
- **IAM Roles**: Instance profiles with minimal permissions
- **SSH Key Access**: Key-based authentication only
- **Database Access**: Restricted to web servers only

## 📊 Monitoring & Backup

### CloudWatch Monitoring
- **CPU Utilization**: Auto scaling triggers
- **Application Health**: Load balancer health checks
- **RDS Metrics**: Database performance monitoring

### Backup Strategy
- **Daily Backups**: Retention for 1 year
- **Weekly Backups**: Retention for 3 years
- **Point-in-time Recovery**: RDS automated backups

## 🔧 Management Commands

### Scale the Application
```bash
# Update desired capacity
terraform apply -var="auto_scaling_desired_capacity=3"
```

### Enable NAT Gateway
```bash
# Enable NAT Gateway (incurs costs)
terraform apply -var="enable_nat_gateway=true"
```

### Access Bastion Host
```bash
# SSH to bastion host (replace with actual IP)
ssh -i your-key.pem ec2-user@bastion-public-ip

# From bastion, connect to private instances
ssh ec2-user@private-instance-ip
```

### Database Access
```bash
# Connect to RDS from bastion host
mysql -h rds-endpoint -u wordpressuser -p wordpress
```

## 🐛 Troubleshooting

### Common Issues

**WordPress Installation Failed**
- Check EC2 instance logs: `/var/log/wordpress-install.log`
- Verify security group rules allow HTTP traffic
- Check RDS connectivity from web servers

**Auto Scaling Not Working**
- Verify CloudWatch alarms are configured
- Check instance health in target group
- Review Auto Scaling Group activity history

**Database Connection Issues**
- Verify RDS security group allows access from web servers
- Check database endpoint in WordPress configuration
- Ensure RDS instance is in "available" state

### Logs and Monitoring
```bash
# View user data logs on EC2 instances
sudo tail -f /var/log/cloud-init-output.log

# Check WordPress installation log
sudo tail -f /var/log/wordpress-install.log

# Monitor Auto Scaling activities
aws autoscaling describe-scaling-activities --auto-scaling-group-name wordpress-asg
```

## 🧹 Cleanup

To avoid ongoing charges, destroy the infrastructure when no longer needed:

```bash
# Destroy all resources
terraform destroy

# Confirm destruction
yes
```

**Note**: Backup data will be retained according to the backup retention policy.

## 📚 Additional Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Free Tier Details](https://aws.amazon.com/free/)
- [WordPress on AWS Best Practices](https://aws.amazon.com/wordpress/)

## 🤝 Contributing

Feel free to submit issues, feature requests, or pull requests to improve this infrastructure template.

## 📄 License

This project is licensed under the MIT License.
