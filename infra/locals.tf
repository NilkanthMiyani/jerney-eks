data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  common_tags = {
    env     = var.environment
    project = "jerney"
  }
  availability_zones = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}
