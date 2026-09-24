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
