variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "adm-cloud-493215"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "europe-west1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "europe-west1-b"
}

variable "minio_root_user" {
  description = "MinIO root user"
  type        = string
  sensitive   = true
}

variable "minio_root_password" {
  description = "MinIO root password"
  type        = string
  sensitive   = true
}

variable "minio_api_user" {
  description = "MinIO API user for the application"
  type        = string
  sensitive   = true
}

variable "minio_api_password" {
  description = "MinIO API password for the application"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT signing secret for the API"
  type        = string
  sensitive   = true
}

variable "auth_users" {
  description = "Comma-separated users for /auth/login: user:pass,user2:pass2"
  type        = string
  sensitive   = true
}
