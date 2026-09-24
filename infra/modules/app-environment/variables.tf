variable "environment_name" {
  description = "Name of this environment e.g dev or staging"
}

variable "instance_type" {
  description = "EC2 instance type"
  type = string
  default = "t3.micro"
}

variable "ami_id" {
  description = "AMI ID to launch"
  type = string
}

variable "subnet_id" {
  description = "Subnet to launch the instance into"
  type = string
}

variable "app_port" {
  description = "Port the application listens on"
  type = number
  default = 3000
}