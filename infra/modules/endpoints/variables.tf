variable "project_name" {
  description = "Project name used for resource names and tags."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "aws_region" {
  description = "AWS region where endpoints will be created."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where endpoints will be created."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for interface endpoints."
  type        = list(string)
}

variable "private_route_table_ids" {
  description = "Private route table IDs for gateway endpoints."
  type        = list(string)
}

variable "vpc_endpoint_security_group_id" {
  description = "Security group ID attached to interface VPC endpoints."
  type        = string
}
