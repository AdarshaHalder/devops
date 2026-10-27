variable "name" {
  description = "Name prefix for ALB, cluster, service and IAM roles (max 29 chars so '<name>-tg' fits the 32-char ALB limit)."
  type        = string

  validation {
    condition     = length(var.name) <= 29
    error_message = "name must be at most 29 characters."
  }
}

variable "aws_region" {
  description = "Region used for the awslogs log driver."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  description = "Subnets for the internet-facing ALB."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Subnets for the Fargate tasks (no public IPs)."
  type        = list(string)
}

variable "certificate_arn" {
  description = "ACM certificate ARN. When set, the ALB serves HTTPS and redirects HTTP to HTTPS."
  type        = string
  default     = ""
}

variable "alb_deletion_protection" {
  type    = bool
  default = false
}

variable "container_image" {
  description = "Container image for the app (a placeholder such as nginx is fine)."
  type        = string
}

variable "container_port" {
  type    = number
  default = 80
}

variable "health_check_path" {
  type    = string
  default = "/"
}

variable "cpu_architecture" {
  description = "X86_64 or ARM64 (Graviton is ~20% cheaper; the image must be multi-arch)."
  type        = string
  default     = "ARM64"

  validation {
    condition     = contains(["X86_64", "ARM64"], var.cpu_architecture)
    error_message = "cpu_architecture must be X86_64 or ARM64."
  }
}

variable "task_cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU)."
  type        = number
}

variable "task_memory" {
  description = "Fargate task memory in MiB."
  type        = number
}

variable "desired_count" {
  description = "Initial task count; autoscaling manages it afterwards."
  type        = number
}

variable "min_capacity" {
  type = number
}

variable "max_capacity" {
  type = number
}

variable "cpu_target_utilization" {
  type    = number
  default = 60
}

variable "use_fargate_spot" {
  description = "Run tasks on FARGATE_SPOT (cheap, interruptible). Intended for non-prod."
  type        = bool
  default     = false
}

variable "container_insights" {
  type    = bool
  default = false
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "environment" {
  description = "Plain-text environment variables for the container."
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Secrets Manager JSON keys injected as environment variables."
  type = list(object({
    name       = string
    secret_arn = string
    key        = string
  }))
  default = []
}
