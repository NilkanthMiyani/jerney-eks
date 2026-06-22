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

variable "cluster_version" {
  description = "EKS control-plane Kubernetes version"
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

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint. Restrict in prod; ignored when endpoint_public_access = false."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
