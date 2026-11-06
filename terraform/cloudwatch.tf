# cloudwatch.tf: Log groups for each environment so Docker/app logs and deployment logs are centralized.
resource "aws_cloudwatch_log_group" "app" {
  for_each          = toset(var.environment_names)
  name              = "/${var.project_name}/${each.key}/app"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "deploy" {
  for_each          = toset(var.environment_names)
  name              = "/${var.project_name}/${each.key}/deploy"
  retention_in_days = 7
}
