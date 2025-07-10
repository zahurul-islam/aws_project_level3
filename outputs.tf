output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "IDs of the database subnets"
  value       = aws_subnet.database[*].id
}

output "load_balancer_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "load_balancer_zone_id" {
  description = "Zone ID of the load balancer"
  value       = aws_lb.main.zone_id
}

output "wordpress_url" {
  description = "URL to access WordPress"
  value       = "http://${aws_lb.main.dns_name}"
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host"
  value       = var.enable_bastion_host ? aws_instance.bastion[0].public_ip : null
}

output "bastion_public_dns" {
  description = "Public DNS of the bastion host"
  value       = var.enable_bastion_host ? aws_instance.bastion[0].public_dns : null
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = var.enable_rds ? aws_db_instance.main[0].endpoint : null
  sensitive   = true
}

output "rds_port" {
  description = "RDS instance port"
  value       = var.enable_rds ? aws_db_instance.main[0].port : null
}

output "nat_gateway_ip" {
  description = "Elastic IP of the NAT Gateway"
  value       = var.enable_nat_gateway ? aws_eip.nat[0].public_ip : null
}

output "backup_vault_name" {
  description = "Name of the backup vault"
  value       = aws_backup_vault.main.name
}

output "security_group_ids" {
  description = "Security group IDs"
  value = {
    alb      = aws_security_group.alb.id
    web      = aws_security_group.web.id
    database = aws_security_group.database.id
    bastion  = var.enable_bastion_host ? aws_security_group.bastion[0].id : null
  }
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.wordpress.name
}

output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.wordpress.id
}

output "deployment_summary" {
  description = "Summary of the deployed infrastructure"
  value = {
    vpc_cidr            = var.vpc_cidr
    availability_zones  = data.aws_availability_zones.available.names
    nat_gateway_enabled = var.enable_nat_gateway
    bastion_enabled     = var.enable_bastion_host
    rds_enabled         = var.enable_rds
    autoscaling_config = {
      min_size         = var.auto_scaling_min_size
      max_size         = var.auto_scaling_max_size
      desired_capacity = var.auto_scaling_desired_capacity
    }
  }
}
