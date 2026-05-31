###############################################################################
# Locals - Valores Derivados y Nomenclatura
# Proyecto: EDUFIS - WordPress en GCP
###############################################################################

locals {
  # ─── Nomenclatura consistente ──────────────────────────────────────────────
  name_prefix = "${var.prefix}-${var.environment}"

  # ─── Etiquetas comunes ─────────────────────────────────────────────────────
  common_labels = merge(var.labels, {
    project     = var.prefix
    environment = var.environment
    managed_by  = "terraform"
    application = "wordpress"
  })

  # ─── Rangos de red aprobados para DEV ─────────────────────────────────────
  environment_network_defaults = {
    dev = {
      app_subnet_name   = "subnet-edufis-app"
      app_subnet_cidr   = "10.133.0.0/25"
      proxy_subnet_name = "subnet-edufis-proxy"
      proxy_subnet_cidr = "10.133.0.128/25"
    }
  }

  selected_network_defaults = lookup(local.environment_network_defaults, var.environment, {})
  app_subnet_name           = lookup(local.selected_network_defaults, "app_subnet_name", "subnet-${var.prefix}-app-${var.environment}")
  proxy_subnet_name         = lookup(local.selected_network_defaults, "proxy_subnet_name", "subnet-${var.prefix}-proxy-${var.environment}")
  app_subnet_cidr           = coalesce(var.subnet_cidr, lookup(local.selected_network_defaults, "app_subnet_cidr", null))
  proxy_subnet_cidr         = coalesce(var.proxy_subnet_cidr, lookup(local.selected_network_defaults, "proxy_subnet_cidr", null))

  # ─── Rangos de IP de Google para health checks y load balancers ────────────
  # Estos son los rangos oficiales de Google para health checks del LB
  google_health_check_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16",
  ]

  # Rango de IAP (Identity-Aware Proxy) para SSH seguro
  google_iap_range = "35.235.240.0/20"

  # ─── Network tags ──────────────────────────────────────────────────────────
  wordpress_tag = "${local.name_prefix}-wordpress"
}
