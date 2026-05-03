resource "google_compute_network" "vpc" {
  name                    = "project-dropbox-vpc"
  auto_create_subnetworks = false
}

# Subnet PRIVADA para os nós GKE (sem IPs externos)
resource "google_compute_subnetwork" "private_subnet" {
  name          = "project-dropbox-subnet-private"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
  purpose       = "PRIVATE"
  
  private_ip_google_access = true  # Permite aceder GCP APIs sem IP externo

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.1.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.2.0.0/16"
  }
}

# Subnet PÚBLICA para o LoadBalancer do NGINX
resource "google_compute_subnetwork" "public_subnet" {
  name          = "project-dropbox-subnet-public"
  ip_cidr_range = "10.0.2.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
  purpose       = "PUBLIC"
}

resource "google_compute_firewall" "allow_https" {
  name    = "project-dropbox-allow-https"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_internal" {
  name    = "project-dropbox-allow-internal"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  source_ranges = ["10.0.0.0/8"]
}

resource "google_compute_firewall" "allow_http" {
  name    = "project-dropbox-allow-http"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_dns_managed_zone" "dropbox_zone" {
  name        = "project-dropbox-zone"
  dns_name    = "project-dropbox.internal."
  description = "Internal DNS zone for project dropbox"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc.id
    }
  }
}
