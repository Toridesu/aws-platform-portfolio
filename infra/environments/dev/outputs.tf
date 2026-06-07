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

output "vpc_endpoint_security_group_id" {
  description = "Security group ID for interface VPC endpoints."
  value       = module.security.vpc_endpoint_security_group_id
}

output "interface_endpoint_ids" {
  description = "Interface VPC endpoint IDs."
  value       = module.endpoints.interface_endpoint_ids
}

output "s3_gateway_endpoint_id" {
  description = "S3 gateway VPC endpoint ID."
  value       = module.endpoints.s3_gateway_endpoint_id
}

output "ecr_repository_url" {
  description = "ECR repository URL for the application image."
  value       = module.ecs.ecr_repository_url
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions deployments."
  value       = module.github_oidc.role_arn
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = module.ecs.ecs_cluster_name
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name."
  value       = module.ecs.alb_dns_name
}

output "budget_name" {
  description = "AWS Budget name."
  value       = module.budgets.budget_name
}
