# ==============================================================
# STAGING variables. Defaults encode the staging environment.
# ==============================================================

variable "aws_region" {
  description = "AWS region — ap-south-1 (Mumbai)"
  type        = string
  default     = "ap-south-1"
  nullable    = false
}

variable "aws_profile" {
  description = "AWS CLI profile name"
  type        = string
  default     = "nilkanthaws9"
  nullable    = false
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "jerney-eks-stg"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,38}[a-z0-9]$", var.cluster_name))
    error_message = "cluster_name must be 3–40 chars, lowercase alphanumeric and hyphens, start with a letter."
  }
}

variable "environment" {
  description = "Environment name — controls resource tags"
  type        = string
  default     = "staging"
  nullable    = false
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.35"
  nullable    = false
}

variable "vpc_cidr" {
  description = "VPC CIDR — staging uses 10.1.0.0/16"
  type        = string
  default     = "10.1.0.0/16"
  nullable    = false
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs (parallel to AZs)"
  type        = list(string)
  default     = ["10.1.0.0/24", "10.1.1.0/24"]
  nullable    = false
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs (parallel to AZs)"
  type        = list(string)
  default     = ["10.1.10.0/24", "10.1.11.0/24"]
  nullable    = false
}

variable "az_count" {
  description = "Number of availability zones to spread subnets across"
  type        = number
  default     = 2
  nullable    = false
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group"
  type        = list(string)
  default     = ["t3.medium"]
  nullable    = false
}

variable "capacity_type" {
  description = "Node capacity type — SPOT in staging for cost savings"
  type        = string
  default     = "SPOT"
  nullable    = false
}

variable "min_node_count" {
  description = "Minimum / initial desired node count"
  type        = number
  default     = 2
  nullable    = false
}

variable "max_node_count" {
  description = "Maximum node count under load"
  type        = number
  default     = 4
  nullable    = false
}

variable "disk_size_gb" {
  description = "Node EBS volume size in GB"
  type        = number
  default     = 50
  nullable    = false
}

variable "endpoint_public_access" {
  description = "Expose the EKS API endpoint publicly"
  type        = bool
  default     = true
  nullable    = false
}

variable "domain_name" {
  description = "Wildcard domain for ACM certificate lookup"
  type        = string
  default     = "*.nilkanthprojects.site"
  nullable    = false
}

variable "acm_certificate_arn" {
  description = "Explicit ACM wildcard certificate ARN for ALB TLS. Empty = look up by domain_name."
  type        = string
  default     = "arn:aws:acm:ap-south-1:310318659882:certificate/9144a150-f7ed-4286-8e3d-18e81950e4ee"
  nullable    = false
}


variable "recovery_window_in_days" {
  description = "Secrets Manager recovery window — 7 days in staging"
  type        = number
  default     = 7
  nullable    = false
}

variable "gitops_repo_url" {
  description = "Git repository ArgoCD's root app watches"
  type        = string
  default     = "https://github.com/NilkanthMiyani/jerney-eks.git"
  nullable    = false
}

variable "gitops_target_revision" {
  description = "Git branch the root app tracks — staging tracks staging"
  type        = string
  default     = "staging"
  nullable    = false
}

variable "gitops_apps_path" {
  description = "Path within the repo holding ArgoCD Application manifests"
  type        = string
  default     = "k8s-eks/apps"
  nullable    = false
}

# ---- Secret values seeded into AWS Secrets Manager (never commit real values) ----

variable "postgres_password" {
  description = "PostgreSQL password — stored as 'jerney-postgres-password'"
  type        = string
  sensitive   = true
  nullable    = false
}

variable "grafana_admin_password" {
  description = "Grafana admin password — stored as 'jerney-grafana-admin-password'"
  type        = string
  sensitive   = true
  nullable    = false
}

variable "alertmanager_smtp_key" {
  description = "Resend SMTP API key — stored as 'jerney-alertmanager-smtp-key'"
  type        = string
  sensitive   = true
  nullable    = false
}
