variable "secrets" {
  description = "Map of secret name => secret value to store in AWS Secrets Manager"
  type        = map(string)
  sensitive   = true
  nullable    = false
}

variable "recovery_window_in_days" {
  description = "Days before a deleted secret is permanently removed. 0 = delete immediately (dev). 7-30 recommended for staging/prod."
  type        = number
  default     = 0
  nullable    = false
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
  nullable    = false
}
