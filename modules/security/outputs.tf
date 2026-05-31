###############################################################################
# Outputs - Módulo Security
###############################################################################

output "service_account_email" {
  description = "Email del service account de WordPress"
  value       = google_service_account.wordpress.email
}

output "service_account_id" {
  description = "ID del service account de WordPress"
  value       = google_service_account.wordpress.id
}

output "cloud_armor_policy_id" {
  description = "ID de la política de Cloud Armor"
  value       = google_compute_security_policy.wordpress.id
}

output "cloud_armor_policy_self_link" {
  description = "Self link de la política de Cloud Armor"
  value       = google_compute_security_policy.wordpress.self_link
}
