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


# Add security outputs to Dev
output "alb_security_group_id" {
  description = "ALB security group ID."
  value       = module.security.alb_security_group_id
}

output "app_security_group_id" {
  description = "Application security group ID."
  value       = module.security.app_security_group_id
}

output "db_security_group_id" {
  description = "Database security group ID."
  value       = module.security.db_security_group_id
}

# Connect IAM to Dev
output "ec2_role_arn" {
  description = "EC2 IAM role ARN."
  value       = module.iam.ec2_role_arn
}

output "ec2_instance_profile_name" {
  description = "EC2 instance profile name."
  value       = module.iam.ec2_instance_profile_name
}