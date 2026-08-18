# ALB outputs
output "alb_id" {
  description = "Application Load Balancer ID."
  value       = aws_lb.this.id
}

output "alb_arn" {
  description = "Application Load Balancer ARN."
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer."
  value       = aws_lb.this.dns_name
}

output "target_group_arn" {
  description = "Application target group ARN."
  value       = aws_lb_target_group.app.arn
}

output "target_group_name" {
  description = "Application target group name."
  value       = aws_lb_target_group.app.name
}

# Add ALB outputs if needed
output "alb_arn_suffix" {
  description = "ALB ARN suffix used for CloudWatch dimensions."
  value       = aws_lb.this.arn_suffix
}

output "target_group_arn_suffix" {
  description = "Target group ARN suffix used for CloudWatch dimensions."
  value       = aws_lb_target_group.app.arn_suffix
}