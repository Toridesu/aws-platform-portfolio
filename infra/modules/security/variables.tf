variable "project_name" {
  description = "Project name used for resource names and tags."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "aws_region" {
  description = "AWS region used to resolve regional AWS service prefix lists."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where security groups will be created."
  type        = string
}

variable "container_port" {
  description = "Application container port exposed by ECS tasks."
  type        = number
  default     = 3000
}
