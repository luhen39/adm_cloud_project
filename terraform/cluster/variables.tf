variable "zone" {
  description = "GCP Zone"
  type        = string
}

variable "vpc_name" {
  description = "VPC Name"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID"
  type        = string
}

variable "service_account_email" {
  description = "Service Account Email for GKE nodes"
  type        = string
}
