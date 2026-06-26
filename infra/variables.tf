variable "aws_region" {
  description = "AWS region"
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "Must be a valid AWS region (e.g. ap-south-1, us-east-1)."
  }
}

variable "aws_profile" {
  description = "AWS CLI profile name"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{1,99}$", var.cluster_name))
    error_message = "Cluster name must start with a letter, contain only alphanumerics and hyphens, and be 2–100 characters."
  }
}

variable "environment" {
  description = "Environment name — controls resource tags"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "cluster_version" {
  description = "EKS control-plane Kubernetes version"
  type        = string

  validation {
    condition     = can(regex("^1\\.[0-9]+$", var.cluster_version))
    error_message = "Cluster version must be a valid Kubernetes minor version (e.g. 1.35)."
  }
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block (e.g. 10.0.0.0/16)."
  }
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs (parallel to AZs)"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs (parallel to AZs)"
  type        = list(string)
}

variable "az_count" {
  description = "Number of availability zones"
  type        = number

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 4
    error_message = "az_count must be between 2 and 4 for HA."
  }
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group"
  type        = list(string)

  validation {
    condition     = length(var.node_instance_types) > 0
    error_message = "At least one instance type must be specified."
  }
}

variable "capacity_type" {
  description = "Node capacity type (SPOT or ON_DEMAND)"
  type        = string

  validation {
    condition     = contains(["SPOT", "ON_DEMAND"], var.capacity_type)
    error_message = "capacity_type must be either SPOT or ON_DEMAND."
  }
}

variable "min_node_count" {
  description = "Minimum / initial desired node count"
  type        = number

  validation {
    condition     = var.min_node_count >= 1
    error_message = "min_node_count must be at least 1."
  }
}

variable "max_node_count" {
  description = "Maximum node count under load"
  type        = number

  validation {
    condition     = var.max_node_count >= 1
    error_message = "max_node_count must be at least 1."
  }
}

variable "disk_size_gb" {
  description = "Node EBS volume size in GB"
  type        = number

  validation {
    condition     = var.disk_size_gb >= 20 && var.disk_size_gb <= 500
    error_message = "disk_size_gb must be between 20 and 500."
  }
}

variable "endpoint_public_access" {
  description = "Expose the EKS API endpoint publicly"
  type        = bool
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint. Restrict in prod; ignored when endpoint_public_access = false."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "single_nat_gateway" {
  description = "If true, provisions a single NAT gateway for the entire VPC (cost-saving for labs). If false, provisions one per AZ (HA for production)."
  type        = bool
}
