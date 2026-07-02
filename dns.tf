###############################################################################
# DNS Records - Opcional si las zonas DNS son administradas por Cloud DNS
# Proyecto: EDUFIS - WordPress en GCP
#
# Si el cliente administra DNS en Windows DNS, Cloudflare u otra plataforma,
# dejar estas variables vacías y usar los outputs como solicitud formal.
###############################################################################

locals {
  external_dns_name = "${trimsuffix(var.domain, ".")}."
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
