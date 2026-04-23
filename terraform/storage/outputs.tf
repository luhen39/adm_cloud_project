output "minio_backup_bucket" {
  value = google_storage_bucket.minio_backup.name
}

output "minio_disk_name" {
  value = google_compute_disk.minio_disk.name
}
