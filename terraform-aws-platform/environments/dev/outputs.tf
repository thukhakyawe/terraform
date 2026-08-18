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

# Add ALB outputs to dev
output "alb_dns_name" {
  description = "DNS name of the application load balancer."
  value       = module.alb.alb_dns_name
}

output "alb_arn" {
  description = "ARN of the application load balancer."
  value       = module.alb.alb_arn
}

output "target_group_arn" {
  description = "ARN of the application target group."
  value       = module.alb.target_group_arn
}

# Add compute outputs
output "autoscaling_group_name" {
  description = "Application Auto Scaling Group name."
  value       = module.compute.autoscaling_group_name
}

output "launch_template_id" {
  description = "Application Launch Template ID."
  value       = module.compute.launch_template_id
}

output "application_ami_id" {
  description = "Amazon Linux AMI used by the application."
  value       = module.compute.ami_id
}

# Add database outputs
output "db_endpoint" {
  description = "RDS PostgreSQL endpoint."
  value       = module.database.db_endpoint
}

output "db_port" {
  description = "RDS PostgreSQL port."
  value       = module.database.db_port
}

output "db_name" {
  description = "Application database name."
  value       = module.database.db_name
}

output "db_secret_arn" {
  description = "ARN of the database credentials secret."
  value       = module.database.secret_arn
}