###############################################################################
# Outputs - Módulo Network
###############################################################################

output "vpc_id" {
  description = "ID de la VPC"
  value       = google_compute_network.vpc.id
}

output "vpc_name" {
  description = "Nombre de la VPC"
  value       = google_compute_network.vpc.name
}

output "vpc_self_link" {
  description = "Self link de la VPC"
  value       = google_compute_network.vpc.self_link
}

output "subnet_id" {
  description = "ID de la subred de WordPress"
  value       = google_compute_subnetwork.wordpress.id
}

output "subnet_name" {
  description = "Nombre de la subred de aplicación"
  value       = google_compute_subnetwork.wordpress.name
}

output "subnet_self_link" {
  description = "Self link de la subred de aplicación"
  value       = google_compute_subnetwork.wordpress.self_link
}

output "subnet_cidr" {
  description = "CIDR de la subred de aplicación"
  value       = google_compute_subnetwork.wordpress.ip_cidr_range
}

output "proxy_subnet_name" {
  description = "Nombre de la proxy-only subnet"
  value       = google_compute_subnetwork.proxy.name
}

output "proxy_subnet_cidr" {
  description = "CIDR de la proxy-only subnet"
  value       = google_compute_subnetwork.proxy.ip_cidr_range
}

output "router_name" {
  description = "Nombre del Cloud Router"
  value       = google_compute_router.router.name
}
