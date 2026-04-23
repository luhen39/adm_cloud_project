resource "google_storage_bucket" "minio_backup" {
  name          = "project-dropbox-minio-backup"
  location      = var.region
  force_destroy = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 30
    }
  }
}

resource "google_compute_disk" "minio_disk" {
  name  = "project-dropbox-minio-disk"
  type  = "pd-standard"
  zone  = var.zone
  size  = 50
}
