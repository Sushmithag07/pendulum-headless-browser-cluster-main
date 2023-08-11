terraform {
  backend "s3" {}
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.17.1"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = local.region
}
