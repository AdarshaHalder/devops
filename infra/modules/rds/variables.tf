variable "name" {
  description = "Identifier prefix for the DB instance and related resources."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "database_subnet_ids" {
  description = "Isolated subnets (no internet route) in at least two AZs."
  type        = list(string)
}

variable "app_security_group_id" {
  description = "Security group of the ECS tasks; the only source allowed on 5432."
  type        = string
}

variable "engine_version" {
  description = "PostgreSQL version. Major-only (e.g. \"16\") lets RDS pick the latest minor."
  type        = string
  default     = "16"
}

variable "instance_class" {
  type = string
}

variable "db_name" {
  type    = string
  default = "hotel_bookings"
}

variable "master_username" {
  type    = string
  default = "app_admin"
}

variable "allocated_storage" {
  description = "Initial storage in GiB."
  type        = number
}

variable "max_allocated_storage" {
  description = "Storage autoscaling ceiling in GiB."
  type        = number
}

variable "multi_az" {
  type = bool
}

variable "backup_retention_days" {
  description = "Automated backup / PITR retention (0-35 days)."
  type        = number

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be between 1 and 35."
  }
}

variable "deletion_protection" {
  description = "Blocks deletion; also controls whether a final snapshot is taken on destroy."
  type        = bool
}

variable "apply_immediately" {
  description = "Apply modifications now instead of in the maintenance window."
  type        = bool
  default     = false
}

variable "performance_insights_enabled" {
  type    = bool
  default = false
}

variable "log_min_duration_ms" {
  description = "Log statements slower than this many milliseconds (-1 disables)."
  type        = number
  default     = 500
}
