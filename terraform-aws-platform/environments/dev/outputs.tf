output "environment" {
  description = "Deployment environment."
  value       = var.environment
}

output "aws_region" {
  description = "AWS region."
  value       = var.aws_region
}

output "vpc_id" {
  description = "Development VPC ID."
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "Development public subnet IDs."
  value       = module.networking.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "Development private application subnet IDs."
  value       = module.networking.private_app_subnet_ids
}

output "private_db_subnet_ids" {
  description = "Development private database subnet IDs."
  value       = module.networking.private_db_subnet_ids
}