terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Primary provider for Cognito and the US compute stack
provider "aws" {
  region = "us-east-1"
  alias  = "us_east_1"
}

# Secondary provider for the EU compute stack
provider "aws" {
  region = "eu-west-1"
  alias  = "eu_west_1"
}