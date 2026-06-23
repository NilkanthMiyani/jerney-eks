terraform {
  required_version = "~> 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    # Terraform Workspaces will automatically prepend `env:/<workspace_name>/` to this key.
    bucket       = "jerney-tfstate-ernpnb"
    key          = "jerney-eks/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
    profile      = "nilkanthaws9"
  }
}
