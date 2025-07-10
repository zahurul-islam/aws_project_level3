# AWS Backup Vault
resource "aws_backup_vault" "main" {
  name        = "${var.project_name}-backup-vault"
  kms_key_arn = aws_kms_key.backup.arn

  tags = {
    Name = "${var.project_name}-backup-vault"
  }
}

# KMS Key for Backup Encryption
resource "aws_kms_key" "backup" {
  description             = "KMS key for backup encryption"
  deletion_window_in_days = 7

  tags = {
    Name = "${var.project_name}-backup-key"
  }
}

# KMS Key Alias
resource "aws_kms_alias" "backup" {
  name          = "alias/${var.project_name}-backup"
  target_key_id = aws_kms_key.backup.key_id
}

# IAM Role for AWS Backup
resource "aws_iam_role" "backup" {
  name = "${var.project_name}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })
}

# Attach AWS Backup service role policy
resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

# Backup Plan
resource "aws_backup_plan" "main" {
  name = "${var.project_name}-backup-plan"

  rule {
    rule_name         = "daily_backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 2 * * ? *)" # Daily at 2 AM

    lifecycle {
      cold_storage_after = 30
      delete_after       = 365
    }

    recovery_point_tags = {
      BackupType = "Daily"
      Project    = var.project_name
    }
  }

  rule {
    rule_name         = "weekly_backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 3 ? * SUN *)" # Weekly on Sunday at 3 AM

    lifecycle {
      cold_storage_after = 30
      delete_after       = 1095 # 3 years
    }

    recovery_point_tags = {
      BackupType = "Weekly"
      Project    = var.project_name
    }
  }

  tags = {
    Name = "${var.project_name}-backup-plan"
  }
}

# Backup Selection for RDS (if enabled)
resource "aws_backup_selection" "rds" {
  count = var.enable_rds ? 1 : 0

  iam_role_arn = aws_iam_role.backup.arn
  name         = "${var.project_name}-rds-backup"
  plan_id      = aws_backup_plan.main.id

  resources = [
    aws_db_instance.main[0].arn
  ]

  condition {
    string_equals {
      key   = "aws:ResourceTag/Project"
      value = var.project_name
    }
  }
}

# Backup Selection for EC2 instances
resource "aws_backup_selection" "ec2" {
  iam_role_arn = aws_iam_role.backup.arn
  name         = "${var.project_name}-ec2-backup"
  plan_id      = aws_backup_plan.main.id

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Project"
    value = var.project_name
  }

  resources = ["*"]
}
