variable "aws_region" {
  description = "AWS region where resources will be created."
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Project name used for resource names and tags."
  type        = string
  default     = "aws-platform-portfolio"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones used by public and private subnets."
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "public_subnets" {
  description = "CIDR blocks for public subnets."
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnets" {
  description = "CIDR blocks for private subnets."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "ecs_desired_count" {
  description = "Number of ECS tasks to run. Keep 0 until ECR image and private subnet egress are ready."
  type        = number
  default     = 0
}

variable "enable_github_oidc" {
  description = "Whether to create GitHub Actions OIDC resources."
  type        = bool
  default     = false
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the deploy role, in owner/repository format."
  type        = string
  default     = ""
}

variable "github_branch" {
  description = "GitHub branch allowed to assume the deploy role."
  type        = string
  default     = "main"
}

variable "enable_budget" {
  description = "Whether to create an AWS Budget for monthly cost monitoring."
  type        = bool
  default     = false
}

variable "budget_monthly_limit_usd" {
  description = "Monthly budget limit in USD."
  type        = string
  default     = "5"
}

variable "budget_notification_email" {
  description = "Email address that receives AWS Budget notifications."
  type        = string
  default     = ""
  sensitive   = true
}

variable "budget_actual_threshold_percent" {
  description = "Actual cost threshold percentage for AWS Budget notification."
  type        = number
  default     = 80
}

variable "budget_forecasted_threshold_percent" {
  description = "Forecasted cost threshold percentage for AWS Budget notification."
  type        = number
  default     = 100
}
