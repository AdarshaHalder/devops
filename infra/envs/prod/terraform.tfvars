environment = "prod"
aws_region  = "ap-south-1"

# Network: 3 AZs, one NAT gateway per AZ so losing an AZ doesn't cut egress.
vpc_cidr           = "10.20.0.0/16"
azs                = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
single_nat_gateway = false

# ALB / ECS: on-demand Fargate, at least 2 tasks across AZs, longer log retention.
# Set certificate_arn to an ACM certificate to enable HTTPS (HTTP then redirects).
certificate_arn         = ""
alb_deletion_protection = true
container_image         = "public.ecr.aws/nginx/nginx:1.27-alpine"
task_cpu                = 1024
task_memory             = 2048
desired_count           = 2
min_capacity            = 2
max_capacity            = 6
use_fargate_spot        = false
container_insights      = true
log_retention_days      = 90

# RDS: memory-optimised Multi-AZ instance, 30 days of PITR, deletion protected
# (a final snapshot is taken if it is ever destroyed).
db_instance_class        = "db.r6g.large"
db_allocated_storage     = 100
db_max_allocated_storage = 500
db_multi_az              = true
db_backup_retention_days = 30
db_deletion_protection   = true
db_apply_immediately     = false
db_performance_insights  = true
