###############################################################################
# Outputs - Módulo Load Balancer
###############################################################################

output "global_ip_address" {
  description = "Dirección IP global del Load Balancer"
  value       = google_compute_global_address.wordpress.address
}

output "global_ip_name" {
  description = "Nombre del recurso de IP global"
  value       = google_compute_global_address.wordpress.name
}

output "backend_service_id" {
  description = "ID del backend service"
  value       = google_compute_backend_service.wordpress.id
}

output "ssl_certificate_id" {
  description = "ID del certificado SSL"
  value       = google_compute_managed_ssl_certificate.wordpress.id
}

output "url_map_id" {
  description = "ID del URL map"
  value       = google_compute_url_map.wordpress.id
}

output "https_proxy_id" {
  description = "ID del HTTPS proxy"
  value       = google_compute_target_https_proxy.wordpress.id
}

output "wordpress_url" {
  description = "URL de WordPress (HTTPS)"
  value       = "https://${var.domain}"
}
