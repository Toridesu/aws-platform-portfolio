output "interface_endpoint_ids" {
  description = "Interface VPC endpoint IDs."
  value       = { for key, endpoint in aws_vpc_endpoint.interface : key => endpoint.id }
}

output "s3_gateway_endpoint_id" {
  description = "S3 gateway VPC endpoint ID."
  value       = aws_vpc_endpoint.s3.id
}
