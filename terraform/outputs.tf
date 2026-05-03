output "project_id" {
  value = var.project_id
}

output "region" {
  value = var.region
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "subnet_id" {
  value = module.network.subnet_id
}

output "vpc_name" {
  value = module.network.vpc_name
}

output "cluster_name" {
  value = module.cluster.cluster_name
}

output "cluster_endpoint" {
  value     = module.cluster.cluster_endpoint
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = module.cluster.cluster_ca_certificate
  sensitive = true
}

output "service_account_email" {
  value = module.iam.service_account_email
}

output "minio_backup_bucket" {
  value = module.storage.minio_backup_bucket
}

output "minio_disk_name" {
  value = module.storage.minio_disk_name
}

output "hpa_name" {
  value = module.hpa.hpa_name
}
