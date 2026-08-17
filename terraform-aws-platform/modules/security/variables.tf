variable "name" {
  description = "Name prefix for security resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where security groups will be created."
  type        = string
}

variable "app_port" {
  description = "Application listening port."
  type        = number
  default     = 8080
}

variable "db_port" {
  description = "Database listening port."
  type        = number
  default     = 5432
}

variable "tags" {
  description = "Additional tags applied to security resources."
  type        = map(string)
  default     = {}
}
