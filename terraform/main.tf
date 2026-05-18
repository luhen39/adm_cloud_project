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

  type = "Opaque"

  string_data = {
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

  type = "Opaque"

  string_data = {
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

  type = "Opaque"

  string_data = {
    ".htpasswd" = var.nginx_htpasswd
  }

  depends_on = [module.cluster]
}

resource "kubernetes_secret" "nginx_tls" {
  metadata {
    name      = "nginx-tls"
    namespace = "default"
  }

  type = "kubernetes.io/tls"

  string_data = {
    "tls.crt" = var.nginx_tls_crt
    "tls.key" = var.nginx_tls_key
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
    backoff_limit            = 5
    ttl_seconds_after_finished = 300

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
            until mc alias set local http://minio-service:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"; do
              echo "Waiting for MinIO..."
              sleep 3
            done

            mc mb --ignore-existing local/files
            mc mb --ignore-existing local/thumbnails
            mc mb --ignore-existing local/tmp

            mc admin user add local "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY" || true

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
                    "arn:aws:s3:::files/*",
                    "arn:aws:s3:::files",
                    "arn:aws:s3:::thumbnails/*",
                    "arn:aws:s3:::thumbnails",
                    "arn:aws:s3:::tmp/*",
                    "arn:aws:s3:::tmp"
                  ]
                }
              ]
            }
            POLICY

            mc admin policy create local api-policy /tmp/api-policy.json || true
            mc admin policy attach local api-policy --user "$MINIO_ACCESS_KEY"
          EOT
          ]

          env_from {
            secret_ref {
              name = kubernetes_secret.minio_secrets.metadata[0].name
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.api_secrets.metadata[0].name
            }
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
