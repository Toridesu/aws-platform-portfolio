output "role_arn" {
  description = "IAM role ARN for GitHub Actions deployments."
  value       = var.enabled ? aws_iam_role.github_actions_deploy[0].arn : null
}

output "oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN."
  value       = var.enabled ? aws_iam_openid_connect_provider.github[0].arn : null
}
