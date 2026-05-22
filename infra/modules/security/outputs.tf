output "alb_security_group_id" {
  description = "Security group ID for the Application Load Balancer."
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "Security group ID for ECS tasks."
  value       = aws_security_group.ecs.id
}

output "vpc_endpoint_security_group_id" {
  description = "Security group ID for interface VPC endpoints."
  value       = aws_security_group.vpc_endpoint.id
}
