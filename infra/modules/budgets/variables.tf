variable "enabled" {
  description = "Whether to create the AWS Budget."
  type        = bool
}

variable "project_name" {
  description = "Project name used for resource names and tags."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "monthly_limit_usd" {
  description = "Monthly budget limit in USD."
  type        = string
}

variable "notification_email" {
  description = "Email address that receives AWS Budget notifications."
  type        = string
}

variable "actual_threshold_percent" {
  description = "Actual cost threshold percentage for notification."
  type        = number
}

variable "forecasted_threshold_percent" {
  description = "Forecasted cost threshold percentage for notification."
  type        = number
}
