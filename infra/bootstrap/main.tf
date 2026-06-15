# ==============================================================
# Bootstrap — creates the S3 bucket and DynamoDB table used as
# the Terraform remote backend for infra/terraform-eks.
# ==============================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

variable "aws_region" {
  description = "AWS region for the state bucket"
  type        = string
  default     = "ap-south-1"
}

variable "aws_profile" {
  description = "AWS CLI profile"
  type        = string
  default     = "nilkanthaws9"
}

# Bucket names must be globally unique
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# ---- S3 Bucket for Terraform state ----
resource "aws_s3_bucket" "tfstate" {
  bucket        = "jerney-tfstate-${random_string.suffix.result}"
  force_destroy = true # allows terraform destroy on cleanup

  tags = {
    project = "jerney"
    purpose = "terraform-state"
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# State locking is handled natively by the S3 backend via `use_lockfile = true`

output "state_bucket_name" {
  description = "Set this as the bucket in infra/terraform-eks/versions.tf backend block"
  value       = aws_s3_bucket.tfstate.id
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}
