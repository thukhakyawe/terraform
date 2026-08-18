variable "name" {
  description = "Name prefix for monitoring resources."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix used by CloudWatch metrics."
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Target group ARN suffix used by CloudWatch metrics."
  type        = string
}

variable "autoscaling_group_name" {
  description = "Auto Scaling Group name."
  type        = string
}

variable "db_instance_identifier" {
  description = "RDS instance identifier."
  type        = string
}

variable "alarm_email" {
  description = "Email address for CloudWatch alarm notifications."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default     = {}
}
