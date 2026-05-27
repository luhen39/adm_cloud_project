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
  source     = "./network"
  region     = var.region
  project_id = var.project_id
}

module "iam" {
  source     = "./iam"
  project_id = var.project_id
}

module "cluster" {
  source                 = "./cluster"
  zone                   = var.zone
  vpc_name               = module.network.vpc_name
  private_subnet_id      = module.network.private_subnet_id
  service_account_email  = module.iam.service_account_email
  project_id             = var.project_id
}

module "storage" {
  source = "./storage"
  region = var.region
  zone   = var.zone
}

module "hpa" {
  source     = "./hpa"
  depends_on = [
    module.cluster,
    kubernetes_manifest.api_deployment
  ]
}

resource "kubernetes_secret" "minio_secrets" {
  metadata {
    name      = "minio-secrets"
    namespace = "default"
  }
  data = {
    MINIO_ROOT_USER     = var.minio_root_user
    MINIO_ROOT_PASSWORD = var.minio_root_password
  }
  depends_on = [module.cluster]
}

resource "kubernetes_secret" "api_secrets" {
  metadata {
    name      = "api-secrets"
    namespace = "default"
  }
  data = {
    MINIO_ACCESS_KEY = var.minio_api_user
    MINIO_SECRET_KEY = var.minio_api_password
    JWT_SECRET       = var.jwt_secret
    AUTH_USERS       = var.auth_users
  }
  depends_on = [module.cluster]
}

resource "kubernetes_secret" "nginx_htpasswd" {
  metadata {
    name      = "nginx-htpasswd"
    namespace = "default"
  }
  data = {
    ".htpasswd" = (file("${path.module}/../nginx/auth/.htpasswd"))
  }
  depends_on = [module.cluster]
}

resource "kubernetes_secret" "nginx_tls" {
  metadata {
    name      = "nginx-tls"
    namespace = "default"
  }
  type = "kubernetes.io/tls"
  data = {
    "tls.crt" = file("${path.module}/../nginx/ssl/tls.crt")
    "tls.key" = file("${path.module}/../nginx/ssl/tls.key")
  }
  depends_on = [module.cluster]
}

resource "kubernetes_job_v1" "minio_init" {
  metadata {
    name      = "minio-init"
    namespace = "default"
    labels = {
      app = "minio-init"
    }
  }

  spec {
    backoff_limit              = 10
    ttl_seconds_after_finished = 300
    active_deadline_seconds    = 900

    template {
      metadata {
        labels = {
          app = "minio-init"
        }
      }

      spec {
        restart_policy = "OnFailure"

        container {
          name  = "minio-init"
          image = "minio/mc:latest"

          command = ["/bin/sh", "-c"]
          args = [<<-EOT
            set -e

            echo "Waiting for MinIO..."
            until mc alias set local http://minio-service:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD; do
              echo "MinIO not ready, retrying in 15s..."
              sleep 15
            done
            echo "MinIO ready!"

            echo "Creating buckets..."
            mc mb --ignore-existing local/files
            mc mb --ignore-existing local/thumbnails
            mc mb --ignore-existing local/tmp
            echo "Buckets created."

            echo "Setting up API user..."
            mc admin user remove local $MINIO_ACCESS_KEY 2>/dev/null || true
            mc admin user add local $MINIO_ACCESS_KEY $MINIO_SECRET_KEY

            mc admin policy remove local api-policy 2>/dev/null || true

            cat <<'POLICY' > /tmp/api-policy.json
            {
              "Version": "2012-10-17",
              "Statement": [
                {
                  "Effect": "Allow",
                  "Action": [
                    "s3:GetObject",
                    "s3:PutObject",
                    "s3:DeleteObject",
                    "s3:ListBucket"
                  ],
                  "Resource": [
                    "arn:aws:s3:::files",
                    "arn:aws:s3:::files/*",
                    "arn:aws:s3:::thumbnails",
                    "arn:aws:s3:::thumbnails/*",
                    "arn:aws:s3:::tmp",
                    "arn:aws:s3:::tmp/*"
                  ]
                }
              ]
            }
            POLICY

            mc admin policy create local api-policy /tmp/api-policy.json
            mc admin policy attach local api-policy --user $MINIO_ACCESS_KEY
            echo "MinIO initialization complete!"
          EOT
          ]

          env {
            name  = "MINIO_ROOT_USER"
            value = var.minio_root_user
          }
          env {
            name  = "MINIO_ROOT_PASSWORD"
            value = var.minio_root_password
          }
          env {
            name  = "MINIO_ACCESS_KEY"
            value = var.minio_api_user
          }
          env {
            name  = "MINIO_SECRET_KEY"
            value = var.minio_api_password
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_secret.minio_secrets,
    kubernetes_secret.api_secrets,
    kubernetes_manifest.minio_service,
    kubernetes_manifest.minio_deployment
  ]
}
