module "user_data" {
  source = "../user-data"
}

# --- IAM Role for the EC2 instance ---

resource "aws_iam_role" "instance_role" {
  name = "${var.environment_name}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "${var.environment_name}-instance-role"
  role = aws_iam_role.instance_role.name
}

# --- Security Group ---

resource "aws_security_group" "app_sg" {
  name        = "${var.environment_name}-sg"
  description = "Security group for ${var.environment_name} environment"

  ingress {
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.environment_name
  }
}

# --- EC2 Instance ---

resource "aws_instance" "app" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.instance_profile.name

  tags = {
    Environment = var.environment_name
    Name        = "${var.environment_name}Server"
  }

  user_data = module.user_data.script

  lifecycle {
    ignore_changes = [user_data]
  }
}

# --- SNS Topic ---

resource "aws_sns_topic" "alerts" {
  name = "${var.environment_name}-alerts"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "status_check_failed" {
  alarm_name          = "${var.environment_name}-status-check-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods   = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Triggers when ${var.environment_name} instance fails either status check"
  treat_missing_data  = "breaching"

  dimensions = {
    InstanceId = aws_instance.app.id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

