# RDS Database Instance (if enabled)
resource "aws_db_instance" "main" {
  count = var.enable_rds ? 1 : 0

  identifier            = "${var.project_name}-database"
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = 100
  storage_type          = "gp2"
  storage_encrypted     = true

  engine         = "mysql"
  engine_version = var.rds_engine_version
  instance_class = var.rds_instance_class

  db_name  = var.wordpress_db_name
  username = var.wordpress_db_username
  password = var.wordpress_db_password

  vpc_security_group_ids = [aws_security_group.database.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  # Backup settings
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  # Performance Insights (free for db.t3.micro)
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  # Monitoring
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring[0].arn

  # Security
  deletion_protection = false
  skip_final_snapshot = true

  # Parameter group for optimization
  parameter_group_name = aws_db_parameter_group.main[0].name

  tags = {
    Name = "${var.project_name}-database"
    Type = "RDS"
  }

  depends_on = [aws_db_subnet_group.main]
}

# DB Parameter Group for MySQL optimization
resource "aws_db_parameter_group" "main" {
  count = var.enable_rds ? 1 : 0

  family = "mysql8.0"
  name   = "${var.project_name}-mysql-params"

  parameter {
    name  = "innodb_buffer_pool_size"
    value = "{DBInstanceClassMemory*3/4}"
  }

  parameter {
    name  = "max_connections"
    value = "100"
  }

  tags = {
    Name = "${var.project_name}-mysql-params"
  }
}

# IAM Role for RDS Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  count = var.enable_rds ? 1 : 0
  name  = "${var.project_name}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })
}

# Attach policy to RDS monitoring role
resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count      = var.enable_rds ? 1 : 0
  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# CloudWatch Log Group for RDS
resource "aws_cloudwatch_log_group" "rds_slow_query" {
  count             = var.enable_rds ? 1 : 0
  name              = "/aws/rds/instance/${var.project_name}-database/slowquery"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-rds-slowquery-logs"
  }
}

# RDS Subnet Group is defined in vpc.tf
