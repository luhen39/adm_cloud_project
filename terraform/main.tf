terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
  backend "gcs" {
    bucket = "project-dropbox-tfstate"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "kubernetes" {
  host                   = "https://${module.cluster.cluster_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.cluster.cluster_ca_certificate)
}

data "google_client_config" "default" {}

module "network" {
  source = "./network"
  region = var.region
}

module "iam" {
  source     = "./iam"
  project_id = var.project_id
}

module "cluster" {
  source                = "./cluster"
  zone                  = var.zone
  vpc_name              = module.network.vpc_name
  subnet_id             = module.network.subnet_id
  service_account_email = module.iam.service_account_email
}

module "storage" {
  source = "./storage"
  region = var.region
  zone   = var.zone
}

module "hpa" {
  source     = "./hpa"
  depends_on = [module.cluster]
}
