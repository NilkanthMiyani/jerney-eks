# ==============================================================
# DEV — Terraform settings, providers, and remote state backend.
# State key isolates dev from staging/prod in the shared bucket.
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
    bucket       = "jerney-tfstate-uxprho" # e.g. jerney-tfstate-abc123
    key          = "jerney-eks/dev/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true # native S3 state locking (.tflock), replaces DynamoDB
    encrypt      = true
    profile      = "nilkanthaws9"
  }
}
