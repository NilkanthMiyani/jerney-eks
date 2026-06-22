# ==============================================================
# ECR repositories for the Jerney application images.
# ==============================================================

resource "aws_ecr_repository" "jerney" {
  for_each = toset(["jerney-frontend", "jerney-backend"])

  name                 = each.value
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}
