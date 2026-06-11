locals {
  name_prefix = "${var.project_name}-${var.environment}"
  oidc_url    = "https://token.actions.githubusercontent.com"
  subject     = "repo:${var.github_repository}:ref:refs/heads/${var.github_branch}"
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.enabled ? 1 : 0

  url = local.oidc_url

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]

  tags = {
    Name = "${local.name_prefix}-github-actions-oidc"
  }
}

resource "aws_iam_role" "github_actions_deploy" {
  count = var.enabled ? 1 : 0

  name = "${local.name_prefix}-github-actions-deploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github[0].arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = local.subject
          }
        }
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-github-actions-deploy-role"
  }

  lifecycle {
    precondition {
      condition     = var.github_repository != ""
      error_message = "github_repository must be set when GitHub Actions OIDC is enabled."
    }
  }
}

resource "aws_iam_role_policy" "github_actions_deploy" {
  count = var.enabled ? 1 : 0

  name = "${local.name_prefix}-github-actions-deploy-policy"
  role = aws_iam_role.github_actions_deploy[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GetEcrAuthorizationToken"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "PushImageToApplicationRepository"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:DescribeRepositories",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
        Resource = var.ecr_repository_arn
      },
      {
        Sid    = "DescribeEcsCluster"
        Effect = "Allow"
        Action = [
          "ecs:DescribeClusters"
        ]
        Resource = var.ecs_cluster_arn
      },
      {
        Sid    = "DeployExistingEcsService"
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService"
        ]
        Resource = var.ecs_service_arn
      },
      {
        Sid    = "DescribeApplicationLoadBalancer"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups"
        ]
        Resource = "*"
      }
    ]
  })
}
