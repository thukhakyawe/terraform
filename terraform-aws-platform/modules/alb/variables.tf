variable "name" {
  description = "Name prefix for ALB resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the ALB will be deployed."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the ALB."
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID attached to the ALB."
  type        = string
}

variable "target_port" {
  description = "Application target port."
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "HTTP path used for target health checks."
  type        = string
  default     = "/health"
}

variable "tags" {
  description = "Additional tags applied to ALB resources."
  type        = map(string)
  default     = {}
}
