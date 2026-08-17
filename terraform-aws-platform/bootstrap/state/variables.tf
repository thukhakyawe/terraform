variable "aws_region" {
  description = "AWS region where the Terraform state bucket is created."
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Project name used for resource naming."
  type        = string
  default     = "terraform-aws-platform"
}
