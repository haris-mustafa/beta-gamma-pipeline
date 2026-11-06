# variables.tf: Central place to change region, project name, instance type, GitHub repo, and email without touching resources.

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used as prefix for resources"
  type        = string
  default     = "cicd-pipeline"
}

variable "instance_type" {
  description = "EC2 instance type for all three environments"
  type        = string
  default     = "t3.small"
}

variable "github_repo" {
  description = "GitHub repo in format ORG/REPO for OIDC trust policy"
  type        = string
  default     = "haris-mustafa/beta-gamma-pipeline"
}

variable "notification_email" {
  description = "Email subscribed to SNS deployment notifications"
  type        = string
  default     = "egnrharis@gmail.com"
}

variable "vpc_cidr" {
  description = "CIDR block for the dedicated VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "key_name" {
  description = "Optional EC2 key pair name (not required since we use SSM)"
  type        = string
  default     = ""
}

variable "environment_names" {
  description = "The three sequential deployment environments"
  type        = list(string)
  default     = ["beta", "gamma", "prod"]
}
