# Dev Environment
module "dev" {
  source           = "./modules/app-environment"
  environment_name = "dev"
  ami_id           = "ami-07524133e69bdba59"
  subnet_id        = "subnet-0696dc1ea6f8ac6bf"
  instance_type    = "t3.micro"
  alert_email      = "hello@ashandwaine.photo"
}
# Staging Environment
module "staging" {
  source           = "./modules/app-environment"
  environment_name = "staging"
  ami_id           = "ami-07524133e69bdba59"
  subnet_id        = "subnet-0696dc1ea6f8ac6bf"
  instance_type    = "t3.micro"
  alert_email      = "hello@ashandwaine.photo"
}
# Environments Variable
locals {
  environments = ["dev", "staging"]
}
# GitHub Actions User
resource "aws_iam_user" "github_actions_ci" {
  name = "github-actions-ci"

  tags = {
    "Purpose" = "github-actions"
  }
}
# IAM policy for GitHub Actions
resource "aws_iam_policy" "github_actions_deploy" {
  name        = "github-actions-deploy-policy"
  description = "A policy scoped to listing tagged EC2 instances, sending SSM commands to a tagged instance using AWS-RunShellScript and checking SSM command status."
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SendCommandToTaggedInstance"
        Effect   = "Allow"
        Action   = "ssm:SendCommand"
        Resource = "arn:aws:ec2:eu-west-2:877973750220:instance/*"
        Condition = {
          StringEquals = {
            "ssm:resourceTag/Environment" = local.environments
          }
        }
      },
      {
        Sid      = "SendCommandDocument"
        Effect   = "Allow"
        Action   = "ssm:SendCommand"
        Resource = "arn:aws:ssm:eu-west-2::document/AWS-RunShellScript"
      },
      {
        Sid      = "CheckCommandStatus"
        Effect   = "Allow"
        Action   = "ssm:GetCommandInvocation"
        Resource = "*"
      },
      {
        Sid      = "LookupInstanceByTag"
        Effect   = "Allow"
        Action   = "ec2:DescribeInstances"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "deploy" {
  user       = aws_iam_user.github_actions_ci.name
  policy_arn = aws_iam_policy.github_actions_deploy.arn
}
# Combined Cloudwatch dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "app-environments-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "CPU Utilization"
          view   = "timeSeries"
          region = "eu-west-2"
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", module.dev.instance_id, { label = "dev" }],
            ["AWS/EC2", "CPUUtilization", "InstanceId", module.staging.instance_id, { label = "staging" }]
          ]
          period = 300
          stat   = "Average"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Status Check Failures"
          view   = "timeSeries"
          region = "eu-west-2"
          metrics = [
            ["AWS/EC2", "StatusCheckFailed", "InstanceId", module.dev.instance_id, { label = "dev" }],
            ["AWS/EC2", "StatusCheckFailed", "InstanceId", module.staging.instance_id, { label = "staging" }]
          ]
          period = 60
          stat   = "Maximum"
        }
      }
    ]
  })
}
# SNS topic
resource "aws_sns_topic" "security_alerts" {
  name = "manual-ssm-command-alerts"
}

resource "aws_sns_topic_subscription" "security_alerts_email" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = "hello@ashandwaine.photo"
}

resource "aws_cloudwatch_event_rule" "manual_ssm_command" {
  name        = "manual-ssm-send-command-detection"
  description = "Fires when an SSM SendCommand call is made by anyone other than the CI automation user"

  event_pattern = jsonencode({
    source      = ["aws.ssm"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["ssm.amazonaws.com"]
      eventName   = ["SendCommand"]
      userIdentity = {
        arn = [{ "anything-but" = "arn:aws:iam::877973750220:user/github-actions-ci" }]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "notify_security_topic" {
  rule      = aws_cloudwatch_event_rule.manual_ssm_command.name
  target_id = "notify-sns"
  arn       = aws_sns_topic.security_alerts.arn
}

resource "aws_sns_topic_policy" "allow_eventbridge_publish" {
  arn = aws_sns_topic.security_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowEventBridgePublish"
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.security_alerts.arn
      }
    ]
  })
}