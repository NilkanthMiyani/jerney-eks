variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  nullable    = false
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  nullable    = false
}

variable "cluster_role_arn" {
  description = "ARN of the EKS cluster control-plane role (from iam module)"
  type        = string
  nullable    = false
}

variable "node_role_arn" {
  description = "ARN of the node group role (from iam module)"
  type        = string
  nullable    = false
}

variable "subnet_ids" {
  description = "All subnet IDs (public + private) for the cluster control plane ENIs"
  type        = list(string)
  nullable    = false
}

variable "private_subnet_ids" {
  description = "Private subnet IDs where node group instances are placed"
  type        = list(string)
  nullable    = false
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group"
  type        = list(string)
  default     = ["t3.medium"]
  nullable    = false
}

variable "capacity_type" {
  description = "Node capacity type: SPOT (cheap, reclaimable) or ON_DEMAND (stable)"
  type        = string
  default     = "SPOT"
  nullable    = false

  validation {
    condition     = contains(["SPOT", "ON_DEMAND"], var.capacity_type)
    error_message = "capacity_type must be SPOT or ON_DEMAND."
  }
}

variable "min_node_count" {
  description = "Minimum (and initial desired) node count"
  type        = number
  default     = 2
  nullable    = false
}

variable "max_node_count" {
  description = "Maximum node count under load"
  type        = number
  default     = 5
  nullable    = false
}

variable "disk_size_gb" {
  description = "Node EBS volume size in GB"
  type        = number
  default     = 30
  nullable    = false
}

variable "endpoint_public_access" {
  description = "Whether the EKS API server is reachable from the public internet"
  type        = bool
  default     = true
  nullable    = false
}

variable "endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint (when enabled)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
  nullable    = false
}

variable "domain_name" {
  description = "Wildcard domain for the ACM certificate lookup (used only when acm_certificate_arn is empty)"
  type        = string
  nullable    = false
}

variable "acm_certificate_arn" {
  description = "Explicit ACM wildcard certificate ARN. Leave empty to look it up by domain_name."
  type        = string
  default     = ""
  nullable    = false
}

variable "node_labels" {
  description = "Kubernetes labels applied to node group nodes"
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
  nullable    = false
}
