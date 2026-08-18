output "autoscaling_group_name" {
  description = "Application Auto Scaling Group name."
  value       = aws_autoscaling_group.app.name
}

output "launch_template_id" {
  description = "Application Launch Template ID."
  value       = aws_launch_template.app.id
}

output "launch_template_version" {
  description = "Application Launch Template version."
  value       = aws_launch_template.app.latest_version
}

output "ami_id" {
  description = "Amazon Linux AMI used by the application."
  value       = data.aws_ami.amazon_linux.id
}
