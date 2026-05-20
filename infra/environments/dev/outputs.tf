output "vpc_id" {
  description = "VPC ID."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = module.network.private_subnet_ids
}

output "alb_security_group_id" {
  description = "Security group ID for the Application Load Balancer."
  value       = module.security.alb_security_group_id
}

output "ecs_security_group_id" {
  description = "Security group ID for ECS tasks."
  value       = module.security.ecs_security_group_id
}

output "ecr_repository_url" {
  description = "ECR repository URL for the application image."
  value       = module.ecs.ecr_repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = module.ecs.ecs_cluster_name
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name."
  value       = module.ecs.alb_dns_name
}
