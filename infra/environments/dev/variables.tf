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
