variable "cluster_name" {
  description = "EKS cluster name — used to name the IAM roles"
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
