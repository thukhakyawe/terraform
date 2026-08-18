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

variable "app_port" {
  description = "Port used by the application."
  type        = number
  default     = 8080
}

variable "db_port" {
  description = "PostgreSQL database port."
  type        = number
  default     = 5432
}

variable "instance_type" {
  description = "EC2 instance type for the application."
  type        = string
  default     = "t3.micro"
}

variable "min_size" {
  description = "Minimum number of application instances."
  type        = number
  default     = 2
}

variable "desired_size" {
  description = "Desired number of application instances."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of application instances."
  type        = number
  default     = 4
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated RDS storage in GB."
  type        = number
  default     = 20
}

variable "db_backup_retention_period" {
  description = "RDS backup retention period in days."
  type        = number
  default     = 7
}

variable "db_multi_az" {
  description = "Whether RDS should use Multi-AZ."
  type        = bool
  default     = false
}

variable "db_deletion_protection" {
  description = "Whether deletion protection is enabled for RDS."
  type        = bool
  default     = false
}