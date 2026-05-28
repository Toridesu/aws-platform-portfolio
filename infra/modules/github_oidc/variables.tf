variable "project_name" {
  description = "Project name used for resource names and tags."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "enabled" {
  description = "Whether to create GitHub Actions OIDC resources."
  type        = bool
  default     = false
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the role, in owner/repository format."
  type        = string
  default     = ""
}

variable "github_branch" {
  description = "GitHub branch allowed to assume the role."
  type        = string
  default     = "main"
}

variable "ecr_repository_arn" {
  description = "ECR repository ARN that GitHub Actions can push images to."
  type        = string
}

variable "ecs_cluster_arn" {
  description = "ECS cluster ARN that GitHub Actions can describe."
  type        = string
}

variable "ecs_service_arn" {
  description = "ECS service ARN that GitHub Actions can update."
  type        = string
}
