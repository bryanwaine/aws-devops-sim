# Dev Environment
module "dev" {
  source           = "./modules/app-environment"
  environment_name = "dev"
  ami_id           = "ami-07524133e69bdba59"
  subnet_id        = "subnet-0696dc1ea6f8ac6bf"
  instance_type    = "t3.micro"
}
# Staging Environment
module "staging" {
  source           = "./modules/app-environment"
  environment_name = "staging"
  ami_id           = "ami-07524133e69bdba59"
  subnet_id        = "subnet-0696dc1ea6f8ac6bf"
  instance_type    = "t3.micro"
}