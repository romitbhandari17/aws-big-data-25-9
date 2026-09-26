# Terraform + provider setup
#
# Using local execution (state stored locally) for this first iteration -
# no TFE/remote backend configured yet.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

# AWS provider - region is passed in per environment via tfvars
provider "aws" {
  region = var.aws_region
}
