variable "project_name" {
  description = "Project name used for resource names and tags."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "aws_region" {
  description = "AWS region where ECS logs will be written."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where ALB and ECS resources will be created."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the Application Load Balancer."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks."
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID for the Application Load Balancer."
  type        = string
}

variable "ecs_security_group_id" {
  description = "Security group ID for ECS tasks."
  type        = string
}

variable "container_port" {
  description = "Application container port."
  type        = number
  default     = 3000
}

variable "desired_count" {
  description = "Number of ECS tasks to run."
  type        = number
  default     = 0
}

variable "task_cpu" {
  description = "CPU units for the Fargate task."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Memory in MiB for the Fargate task."
  type        = number
  default     = 512
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days."
  type        = number
  default     = 7
}
