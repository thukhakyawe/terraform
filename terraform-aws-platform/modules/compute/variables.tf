variable "name" {
  description = "Name prefix for compute resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the application."
  type        = string
}

variable "private_app_subnet_ids" {
  description = "Private application subnet IDs."
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group attached to application instances."
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN."
  type        = string
}

variable "instance_profile_name" {
  description = "IAM instance profile name for EC2."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "min_size" {
  description = "Minimum number of instances."
  type        = number
  default     = 2
}

variable "desired_size" {
  description = "Desired number of instances."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances."
  type        = number
  default     = 4
}

variable "tags" {
  description = "Additional resource tags."
  type        = map(string)
  default     = {}
}
