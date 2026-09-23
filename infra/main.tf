terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws",
        version = "~> 5.0"
    }
  }
}
# Standard provider for London
provider "aws" {
  region = "eu-west-2"
}


