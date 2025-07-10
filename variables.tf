variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "development"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "aws-capstone-level3"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for database subnets"
  type        = list(string)
  default     = ["10.0.5.0/24", "10.0.6.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro" # Free tier eligible
}

variable "key_pair_name" {
  description = "Name of the EC2 Key Pair"
  type        = string
  default     = ""
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway (incurs costs)"
  type        = bool
  default     = false
}

variable "enable_bastion_host" {
  description = "Enable Bastion Host for secure access"
  type        = bool
  default     = true
}

variable "enable_rds" {
  description = "Enable RDS database (replaces local database)"
  type        = bool
  default     = true
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro" # Free tier eligible
}

variable "rds_engine_version" {
  description = "MySQL engine version for RDS"
  type        = string
  default     = "8.0"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20 # Free tier limit
}

variable "wordpress_db_name" {
  description = "WordPress database name"
  type        = string
  default     = "wordpress"
}

variable "wordpress_db_username" {
  description = "WordPress database username"
  type        = string
  default     = "wordpressuser"
}

variable "wordpress_db_password" {
  description = "WordPress database password"
  type        = string
  default     = "ChangeMe123!"
  sensitive   = true
}

variable "auto_scaling_min_size" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = 1
}

variable "auto_scaling_max_size" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = 3
}

variable "auto_scaling_desired_capacity" {
  description = "Desired number of instances in ASG"
  type        = number
  default     = 2
}
