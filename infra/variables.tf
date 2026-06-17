variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI profile name"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "environment" {
  description = "Environment name — controls resource tags"
  type        = string
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
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
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group"
  type        = list(string)
}

variable "capacity_type" {
  description = "Node capacity type (SPOT or ON_DEMAND)"
  type        = string
}

variable "min_node_count" {
  description = "Minimum / initial desired node count"
  type        = number
}

variable "max_node_count" {
  description = "Maximum node count under load"
  type        = number
}

variable "disk_size_gb" {
  description = "Node EBS volume size in GB"
  type        = number
}

variable "endpoint_public_access" {
  description = "Expose the EKS API endpoint publicly"
  type        = bool
}

variable "domain_name" {
  description = "Wildcard domain for ACM certificate lookup"
  type        = string
}

variable "acm_certificate_arn" {
  description = "Explicit ACM wildcard certificate ARN for ALB TLS. Empty = look up by domain_name."
  type        = string
}

variable "recovery_window_in_days" {
  description = "Secrets Manager recovery window"
  type        = number
}

variable "gitops_repo_url" {
  description = "Git repository ArgoCD's root app watches"
  type        = string
}

variable "gitops_target_revision" {
  description = "Git branch the root app tracks"
  type        = string
}

variable "gitops_apps_path" {
  description = "Path within the repo holding ArgoCD Application manifests"
  type        = string
}

variable "ca_chart_version" {
  description = "Helm chart version for the Kubernetes Cluster Autoscaler"
  type        = string
  default     = "9.57.0"
}

variable "postgres_password" {
  description = "PostgreSQL password — stored as 'jerney-postgres-password'"
  type        = string
  sensitive   = true
}

variable "grafana_admin_password" {
  description = "Grafana admin password — stored as 'jerney-grafana-admin-password'"
  type        = string
  sensitive   = true
}

variable "alertmanager_smtp_key" {
  description = "Resend SMTP API key — stored as 'jerney-alertmanager-smtp-key'"
  type        = string
  sensitive   = true
}
