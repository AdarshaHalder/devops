environment = "dev"
aws_region  = "ap-south-1"

# Network: 2 AZs, one shared NAT gateway to keep cost down.
vpc_cidr           = "10.10.0.0/16"
azs                = ["ap-south-1a", "ap-south-1b"]
single_nat_gateway = true

# ALB / ECS: smallest Fargate size, Spot capacity, short log retention.
alb_deletion_protection = false
container_image         = "public.ecr.aws/nginx/nginx:1.27-alpine"
task_cpu                = 256
task_memory             = 512
desired_count           = 1
min_capacity            = 1
max_capacity            = 2
use_fargate_spot        = true
container_insights      = false
log_retention_days      = 7

# RDS: burstable single-AZ instance, 1 day of backups, easy to tear down.
db_instance_class        = "db.t4g.micro"
db_allocated_storage     = 20
db_max_allocated_storage = 50
db_multi_az              = false
db_backup_retention_days = 1
db_deletion_protection   = false
db_apply_immediately     = true
db_performance_insights  = false
