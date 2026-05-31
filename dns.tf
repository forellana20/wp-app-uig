###############################################################################
# DNS Records - Opcional si las zonas DNS son administradas por Cloud DNS
# Proyecto: EDUFIS - WordPress en GCP
#
# Si el cliente administra DNS en Windows DNS, Cloudflare u otra plataforma,
# dejar estas variables vacías y usar los outputs como solicitud formal.
###############################################################################

locals {
  external_dns_name = "${trimsuffix(var.domain, ".")}."
  internal_dns_name = var.internal_domain != "" ? "${trimsuffix(var.internal_domain, ".")}." : null

  certificate_dns_authorization_zone = (
    var.certificate_dns_authorization_managed_zone != ""
    ? var.certificate_dns_authorization_managed_zone
    : var.public_dns_managed_zone
  )
}

resource "google_dns_record_set" "external_wordpress_a" {
  count = var.public_dns_managed_zone != "" ? 1 : 0

  project      = var.project_id
  managed_zone = var.public_dns_managed_zone
  name         = local.external_dns_name
  type         = "A"
  ttl          = 300
  rrdatas      = [module.load_balancer.global_ip_address]
}

resource "google_dns_record_set" "internal_wordpress_a" {
  count = var.internal_domain != "" && var.internal_dns_managed_zone != "" ? 1 : 0

  project      = var.project_id
  managed_zone = var.internal_dns_managed_zone
  name         = local.internal_dns_name
  type         = "A"
  ttl          = 300
  rrdatas      = [module.load_balancer.internal_ip_address]
}

resource "google_dns_record_set" "internal_certificate_authorization_cname" {
  count = var.internal_domain != "" && local.certificate_dns_authorization_zone != "" ? 1 : 0

  project      = var.project_id
  managed_zone = local.certificate_dns_authorization_zone
  name         = module.load_balancer.internal_dns_authorization_record_name
  type         = module.load_balancer.internal_dns_authorization_record_type
  ttl          = 300
  rrdatas      = [module.load_balancer.internal_dns_authorization_record_data]
}
