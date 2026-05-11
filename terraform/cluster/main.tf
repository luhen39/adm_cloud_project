resource "google_container_cluster" "primary" {
  name     = "project-dropbox-cluster"
  location = var.zone
  deletion_protection = false
  network    = var.vpc_name
  subnetwork = var.private_subnet_id

  remove_default_node_pool = true
  initial_node_count       = 1

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name     = "project-dropbox-node-pool"
  location = var.zone
  cluster  = google_container_cluster.primary.name

  initial_node_count = 2

  autoscaling {
    min_node_count = 2
    max_node_count = 5
  }

  node_config {
    machine_type = "e2-medium"
    disk_size_gb = 30

    service_account = var.service_account_email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}
