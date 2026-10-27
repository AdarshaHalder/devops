output "alb_dns_name" {
  description = "Public entry point."
  value       = module.ecs.alb_dns_name
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "ecs_service_name" {
  value = module.ecs.service_name
}

output "rds_address" {
  description = "Private DNS name; resolvable and reachable only from inside the VPC."
  value       = module.rds.address
}

output "rds_master_user_secret_arn" {
  value = module.rds.master_user_secret_arn
}
