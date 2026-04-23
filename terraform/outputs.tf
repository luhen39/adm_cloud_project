output "project_id" {
  value = var.project_id
}

output "region" {
  value = var.region
}

# Network outputs
output "vpc_id" {
  value = module.network.vpc_id
}

output "subnet_id" {
  value = module.network.subnet_id
}

output "vpc_name" {
  value = module.network.vpc_name
}

# Cluster outputs
output "cluster_name" {
  value = module.cluster.cluster_name
}

output "cluster_endpoint" {
  value     = module.cluster.cluster_endpoint
  sensitive = true
}

# IAM outputs
output "service_account_email" {
  value = module.iam.service_account_email
}

# Storage outputs
output "minio_backup_bucket" {
  value = module.storage.minio_backup_bucket
}

output "minio_disk_name" {
  value = module.storage.minio_disk_name
}
