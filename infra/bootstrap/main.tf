# ==============================================================
# Bootstrap — creates the S3 bucket and DynamoDB table used as
# the Terraform remote backend for infra/terraform-eks.
#
# Uses local state intentionally — this module is the
# prerequisite that makes remote state possible.
# Run once before working in terraform-eks:
#   terraform init && terraform apply
#
# AWS equivalent of:
#   GKE:  google_storage_bucket (GCS)
#   AKS:  azurerm_storage_account + azurerm_storage_container (Blob)
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
    status = "Enabled" # keeps state history, mirrors GCS/Azure versioning
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

# ---- DynamoDB table for state locking ----
# Prevents concurrent `terraform apply` runs from corrupting state.
# GCS uses built-in locking; Azure Blob uses lease-based locking.
# AWS S3 backend requires an explicit DynamoDB table.
# Free tier covers 25 GB + 25 RCU/WCU — a lock table uses negligible resources.
resource "aws_dynamodb_table" "tfstate_lock" {
  name         = "jerney-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST" # zero cost when idle
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    project = "jerney"
    purpose = "terraform-state-lock"
  }
}

output "state_bucket_name" {
  description = "Set this as the bucket in infra/terraform-eks/versions.tf backend block"
  value       = aws_s3_bucket.tfstate.id
}

output "dynamodb_table_name" {
  description = "DynamoDB table for state locking"
  value       = aws_dynamodb_table.tfstate_lock.name
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}
