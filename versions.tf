# Terraform version constraints
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.0.0"
    }
  }

  # Uncomment and configure for remote state storage
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "aws-capstone-level3/terraform.tfstate"
  #   region = "us-east-1"
  #   
  #   # Optional: DynamoDB table for state locking
  #   dynamodb_table = "terraform-state-lock"
  #   encrypt        = true
  # }
}
