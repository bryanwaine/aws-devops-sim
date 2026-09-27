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
          title   = "CPU Utilization"
          view    = "timeSeries"
          region  = "eu-west-2"
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
          title   = "Status Check Failures"
          view    = "timeSeries"
          region  = "eu-west-2"
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