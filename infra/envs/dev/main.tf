locals {
  name = "${var.project}-${var.environment}"
}

module "network" {
  source = "../../modules/network"

  name               = local.name
  vpc_cidr           = var.vpc_cidr
  azs                = var.azs
  single_nat_gateway = var.single_nat_gateway
}

module "ecs" {
  source = "../../modules/ecs"

  name               = local.name
  aws_region         = var.aws_region
  vpc_id             = module.network.vpc_id
  public_subnet_ids  = module.network.public_subnet_ids
  private_subnet_ids = module.network.private_subnet_ids

  certificate_arn         = var.certificate_arn
  alb_deletion_protection = var.alb_deletion_protection

  container_image    = var.container_image
  container_port     = var.container_port
  task_cpu           = var.task_cpu
  task_memory        = var.task_memory
  desired_count      = var.desired_count
  min_capacity       = var.min_capacity
  max_capacity       = var.max_capacity
  use_fargate_spot   = var.use_fargate_spot
  container_insights = var.container_insights
  log_retention_days = var.log_retention_days

  environment = {
    APP_ENV = var.environment
    DB_HOST = module.rds.address
    DB_PORT = tostring(module.rds.port)
    DB_NAME = module.rds.db_name
  }

  secrets = [
    { name = "DB_USERNAME", secret_arn = module.rds.master_user_secret_arn, key = "username" },
    { name = "DB_PASSWORD", secret_arn = module.rds.master_user_secret_arn, key = "password" },
  ]
}

module "rds" {
  source = "../../modules/rds"

  name                  = local.name
  vpc_id                = module.network.vpc_id
  database_subnet_ids   = module.network.database_subnet_ids
  app_security_group_id = module.ecs.service_security_group_id

  engine_version               = var.db_engine_version
  instance_class               = var.db_instance_class
  allocated_storage            = var.db_allocated_storage
  max_allocated_storage        = var.db_max_allocated_storage
  multi_az                     = var.db_multi_az
  backup_retention_days        = var.db_backup_retention_days
  deletion_protection          = var.db_deletion_protection
  apply_immediately            = var.db_apply_immediately
  performance_insights_enabled = var.db_performance_insights
}
