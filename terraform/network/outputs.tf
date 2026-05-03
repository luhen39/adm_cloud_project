output "vpc_id" {
  value = google_compute_network.vpc.id
}

output "private_subnet_id" {
  value = google_compute_subnetwork.private_subnet.id
}

output "public_subnet_id" {
  value = google_compute_subnetwork.public_subnet.id
}

output "vpc_name" {
  value = google_compute_network.vpc.name
}
