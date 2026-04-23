terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
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

module "network" {
  source = "./network"
  region = var.region
}

module "cluster" {
  source                = "./cluster"
  zone                  = var.zone
  vpc_name              = module.network.vpc_name
  subnet_id             = module.network.subnet_id
  service_account_email = module.iam.service_account_email
}

module "iam" {
  source     = "./iam"
  project_id = var.project_id
}

module "storage" {
  source = "./storage"
  region = var.region
  zone   = var.zone
}
