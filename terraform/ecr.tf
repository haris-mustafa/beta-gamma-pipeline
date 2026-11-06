# ecr.tf: Single ECR repository where CI builds ONE Docker image that is promoted across beta/gamma/prod.
resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}/app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}
