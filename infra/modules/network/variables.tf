variable "project_name" {
  description = "Project name used for resource names and tags."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "availability_zones" {
  description = "Availability zones used by public and private subnets."
  type        = list(string)
}

variable "public_subnets" {
  description = "CIDR blocks for public subnets."
  type        = list(string)

  validation {
    condition     = length(var.public_subnets) == length(var.availability_zones)
    error_message = "public_subnets must have the same length as availability_zones."
  }
}

variable "private_subnets" {
  description = "CIDR blocks for private subnets."
  type        = list(string)

  validation {
    condition     = length(var.private_subnets) == length(var.availability_zones)
    error_message = "private_subnets must have the same length as availability_zones."
  }
}
