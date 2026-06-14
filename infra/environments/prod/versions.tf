# ==============================================================
# PROD — Terraform settings, providers, and remote state backend.
# ==============================================================

terraform {
  required_version = "~> 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }

  # Fill in bucket from `terraform output state_bucket_name` in infra/bootstrap/.
  backend "s3" {
    bucket         = "REPLACE_WITH_BOOTSTRAP_OUTPUT" # e.g. jerney-tfstate-abc123
    key            = "jerney-eks/prod/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "jerney-tfstate-lock"
    encrypt        = true
    profile        = "nilkanthaws9"
  }
}
