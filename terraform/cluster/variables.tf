variable "zone" {
  description = "GCP Zone"
  type        = string
}

variable "vpc_name" {
  description = "VPC Name"
  type        = string
}

variable "private_subnet_id" {
  description = "Private Subnet ID"
  type        = string
}

variable "service_account_email" {
  description = "Service Account Email for GKE nodes"
  type        = string
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}
