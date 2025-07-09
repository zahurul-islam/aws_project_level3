# Launch Template for WordPress instances
resource "aws_launch_template" "wordpress" {
  name_prefix   = "${var.project_name}-wordpress-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = var.key_pair_name != "" ? var.key_pair_name : null

  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = local.wordpress_userdata

  iam_instance_profile {
    name = aws_iam_instance_profile.wordpress.name
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 8
      volume_type = "gp2"
      encrypted   = true
    }
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-wordpress"
      Type = "WebServer"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group for WordPress instances
resource "aws_autoscaling_group" "wordpress" {
  name                = "${var.project_name}-wordpress-asg"
  vpc_zone_identifier = aws_subnet.private[*].id
  target_group_arns   = [aws_lb_target_group.wordpress.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  min_size         = var.auto_scaling_min_size
  max_size         = var.auto_scaling_max_size
  desired_capacity = var.auto_scaling_desired_capacity

  launch_template {
    id      = aws_launch_template.wordpress.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-wordpress-asg"
    propagate_at_launch = false
  }
}

# Auto Scaling Policies
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.project_name}-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown              = 300
  autoscaling_group_name = aws_autoscaling_group.wordpress.name
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.project_name}-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown              = 300
  autoscaling_group_name = aws_autoscaling_group.wordpress.name
}

# CloudWatch Alarms for Auto Scaling
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.wordpress.name
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.project_name}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "10"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.wordpress.name
  }
}# Bastion Host (if enabled)
resource "aws_instance" "bastion" {
  count = var.enable_bastion_host ? 1 : 0

  ami                    = data.aws_ami.amazon_linux.id
  instance_type         = var.instance_type
  key_name              = var.key_pair_name != "" ? var.key_pair_name : null
  subnet_id             = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.bastion[0].id]

  user_data = local.bastion_userdata

  iam_instance_profile = aws_iam_instance_profile.bastion[0].name

  root_block_device {
    volume_size = 8
    volume_type = "gp2"
    encrypted   = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name = "${var.project_name}-bastion"
    Type = "BastionHost"
  }
}

# IAM Role for WordPress instances
resource "aws_iam_role" "wordpress" {
  name = "${var.project_name}-wordpress-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for WordPress instances
resource "aws_iam_role_policy" "wordpress" {
  name = "${var.project_name}-wordpress-policy"
  role = aws_iam_role.wordpress.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:CreateLogStream"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Instance Profile for WordPress
resource "aws_iam_instance_profile" "wordpress" {
  name = "${var.project_name}-wordpress-profile"
  role = aws_iam_role.wordpress.name
}

# IAM Role for Bastion Host (if enabled)
resource "aws_iam_role" "bastion" {
  count = var.enable_bastion_host ? 1 : 0
  name  = "${var.project_name}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Bastion Host
resource "aws_iam_role_policy" "bastion" {
  count = var.enable_bastion_host ? 1 : 0
  name  = "${var.project_name}-bastion-policy"
  role  = aws_iam_role.bastion[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeImages",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeSnapshots",
          "ec2:DescribeSecurityGroups",
          "cloudwatch:PutMetricData",
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:CreateLogStream"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Instance Profile for Bastion Host
resource "aws_iam_instance_profile" "bastion" {
  count = var.enable_bastion_host ? 1 : 0
  name  = "${var.project_name}-bastion-profile"
  role  = aws_iam_role.bastion[0].name
}
