variable "project" {
  type    = string
  default = "hotel-bookings"
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

# --- network -----------------------------------------------------------------

variable "vpc_cidr" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "single_nat_gateway" {
  type = bool
}

# --- ALB / ECS ---------------------------------------------------------------

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS; leave empty to serve plain HTTP."
  type        = string
  default     = ""
}

variable "alb_deletion_protection" {
  type = bool
}

variable "container_image" {
  type = string
}

variable "container_port" {
  type    = number
  default = 80
}

variable "task_cpu" {
  type = number
}

variable "task_memory" {
  type = number
}

variable "desired_count" {
  type = number
}

variable "min_capacity" {
  type = number
}

variable "max_capacity" {
  type = number
}

variable "use_fargate_spot" {
  type = bool
}

variable "container_insights" {
  type = bool
}

variable "log_retention_days" {
  type = number
}

# --- RDS ---------------------------------------------------------------------

variable "db_engine_version" {
  type    = string
  default = "16"
}

variable "db_instance_class" {
  type = string
}

variable "db_allocated_storage" {
  type = number
}

variable "db_max_allocated_storage" {
  type = number
}

variable "db_multi_az" {
  type = bool
}

variable "db_backup_retention_days" {
  type = number
}

variable "db_deletion_protection" {
  type = bool
}

variable "db_apply_immediately" {
  type = bool
}

variable "db_performance_insights" {
  type = bool
}
