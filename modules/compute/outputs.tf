###############################################################################
# Outputs - Modulo Compute
###############################################################################

output "instance_name" {
  description = "Nombre de la VM de WordPress"
  value       = google_compute_instance.wordpress.name
}

output "instance_self_link" {
  description = "Self link de la VM de WordPress"
  value       = google_compute_instance.wordpress.self_link
}

output "instance_internal_ip" {
  description = "IP interna de la VM de WordPress"
  value       = google_compute_instance.wordpress.network_interface[0].network_ip
}

output "instance_group_id" {
  description = "ID del unmanaged instance group"
  value       = google_compute_instance_group.wordpress.id
}

output "instance_group_self_link" {
  description = "Self link del unmanaged instance group"
  value       = google_compute_instance_group.wordpress.self_link
}
