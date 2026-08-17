output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of public subnets."
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "private_app_subnet_ids" {
  description = "IDs of private application subnets."
  value       = [for subnet in aws_subnet.private_app : subnet.id]
}

output "private_db_subnet_ids" {
  description = "IDs of private database subnets."
  value       = [for subnet in aws_subnet.private_db : subnet.id]
}

output "availability_zones" {
  description = "Availability Zones used by the network."
  value       = var.availability_zones
}
