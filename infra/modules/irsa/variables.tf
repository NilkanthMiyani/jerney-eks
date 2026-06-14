variable "cluster_name" {
  description = "EKS cluster name — used to name the IRSA roles and target the EBS CSI addon"
  type        = string
  nullable    = false
}

variable "oidc_provider" {
  description = "OIDC provider URL without the https:// prefix (from eks-cluster module)"
  type        = string
  nullable    = false
}

variable "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider (from eks-cluster module)"
  type        = string
  nullable    = false
}

variable "alb_controller_policy_version" {
  description = "Git tag of aws-load-balancer-controller whose iam_policy.json is fetched"
  type        = string
  default     = "v2.11.0"
  nullable    = false
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
  nullable    = false
}
