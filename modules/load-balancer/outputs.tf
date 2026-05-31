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

output "internal_ip_address" {
  description = "Dirección IP privada del Internal Application Load Balancer"
  value       = var.internal_domain != "" ? google_compute_address.wordpress_internal[0].address : null
}

output "internal_wordpress_url" {
  description = "URL interna de WordPress (HTTPS)"
  value       = var.internal_domain != "" ? "https://${var.internal_domain}" : null
}

output "internal_dns_authorization_record_name" {
  description = "Nombre del registro DNS requerido para autorizar el certificado interno"
  value       = var.internal_domain != "" ? google_certificate_manager_dns_authorization.wordpress_internal[0].dns_resource_record[0].name : null
}

output "internal_dns_authorization_record_type" {
  description = "Tipo del registro DNS requerido para autorizar el certificado interno"
  value       = var.internal_domain != "" ? google_certificate_manager_dns_authorization.wordpress_internal[0].dns_resource_record[0].type : null
}

output "internal_dns_authorization_record_data" {
  description = "Valor del registro DNS requerido para autorizar el certificado interno"
  value       = var.internal_domain != "" ? google_certificate_manager_dns_authorization.wordpress_internal[0].dns_resource_record[0].data : null
}
