data "aws_ec2_managed_prefix_list" "s3" {
  name = "com.amazonaws.${var.aws_region}.s3"
}

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Security group for the public Application Load Balancer."
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-${var.environment}-alb-sg"
    Role = "alb"
  }
}

resource "aws_security_group" "ecs" {
  name        = "${var.project_name}-${var.environment}-ecs-sg"
  description = "Security group for private ECS tasks."
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-sg"
    Role = "ecs"
  }
}

resource "aws_security_group" "vpc_endpoint" {
  name        = "${var.project_name}-${var.environment}-vpce-sg"
  description = "Security group for interface VPC endpoints."
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-${var.environment}-vpce-sg"
    Role = "vpc-endpoint"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http_from_internet" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP access from the internet to the ALB."

  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_ecs" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.ecs.id
  description                  = "Allow ALB traffic to ECS tasks."

  ip_protocol = "tcp"
  from_port   = var.container_port
  to_port     = var.container_port
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id            = aws_security_group.ecs.id
  referenced_security_group_id = aws_security_group.alb.id
  description                  = "Allow ECS tasks to receive traffic only from the ALB."

  ip_protocol = "tcp"
  from_port   = var.container_port
  to_port     = var.container_port
}

resource "aws_vpc_security_group_egress_rule" "ecs_https_to_vpc_endpoints" {
  security_group_id            = aws_security_group.ecs.id
  referenced_security_group_id = aws_security_group.vpc_endpoint.id
  description                  = "Allow ECS tasks to reach interface VPC endpoints over HTTPS."

  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
}

resource "aws_vpc_security_group_egress_rule" "ecs_https_to_s3" {
  security_group_id = aws_security_group.ecs.id
  prefix_list_id    = data.aws_ec2_managed_prefix_list.s3.id
  description       = "Allow ECS tasks to reach S3 over HTTPS for ECR image layer downloads."

  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
}

resource "aws_vpc_security_group_ingress_rule" "vpc_endpoint_https_from_ecs" {
  security_group_id            = aws_security_group.vpc_endpoint.id
  referenced_security_group_id = aws_security_group.ecs.id
  description                  = "Allow ECS tasks to reach interface VPC endpoints over HTTPS."

  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
}

resource "aws_vpc_security_group_egress_rule" "vpc_endpoint_all_outbound" {
  security_group_id = aws_security_group.vpc_endpoint.id
  description       = "Allow VPC endpoints to respond to requests."

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}
