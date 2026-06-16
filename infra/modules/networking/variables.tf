variable "cluster_name" {
  description = "EKS cluster name — used for resource names and kubernetes.io/cluster tags"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZ names to spread subnets across (drives the for_each keys). Pass from a data source in the composition."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 availability zones are required for EKS / ALB."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, parallel to availability_zones"
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets, parallel to availability_zones"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
