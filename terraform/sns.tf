# sns.tf: Topic + email subscription used only for production success, rollback success, and rollback failure notifications.
resource "aws_sns_topic" "deploy" {
  name = "${var.project_name}-deploy-notifications"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.deploy.arn
  protocol  = "email"
  endpoint  = var.notification_email
}
