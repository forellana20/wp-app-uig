###############################################################################
# VPN Site-to-Site estatica hacia on-premise
# Proyecto: EDUFIS - WordPress en GCP
#
# Se usa Classic VPN porque el cliente solicito rutas estaticas y no BGP.
# HA VPN requiere Cloud Router/BGP para el intercambio dinamico de rutas.
###############################################################################

locals {
  vpn_remote_cidrs_effective = length(var.vpn_remote_cidrs) > 0 ? var.vpn_remote_cidrs : (
    var.vpn_cidr != "" ? [var.vpn_cidr] : []
  )

  vpn_shared_secret_effective = var.vpn_shared_secret != "" ? var.vpn_shared_secret : (
    var.vpn_enabled ? random_password.vpn_shared_secret[0].result : ""
  )
}

resource "random_password" "vpn_shared_secret" {
  count = var.vpn_enabled && var.vpn_shared_secret == "" ? 1 : 0

  length           = 32
  special          = true
  override_special = "-_"
}

resource "google_compute_address" "vpn_gateway" {
  count = var.vpn_enabled ? 1 : 0

  name         = "${local.name_prefix}-vpn-ip"
  project      = var.project_id
  region       = var.region
  address_type = "EXTERNAL"

  labels = local.common_labels
}

resource "google_compute_vpn_gateway" "classic" {
  count = var.vpn_enabled ? 1 : 0

  name    = "${local.name_prefix}-vpn-gateway"
  project = var.project_id
  region  = var.region
  network = module.network.vpc_self_link

  description = "Classic VPN gateway para rutas estaticas hacia on-premise - ${local.name_prefix}"
}

resource "google_compute_forwarding_rule" "vpn_esp" {
  count = var.vpn_enabled ? 1 : 0

  name        = "${local.name_prefix}-vpn-esp"
  project     = var.project_id
  region      = var.region
  ip_protocol = "ESP"
  ip_address  = google_compute_address.vpn_gateway[0].address
  target      = google_compute_vpn_gateway.classic[0].id
}

resource "google_compute_forwarding_rule" "vpn_udp_500" {
  count = var.vpn_enabled ? 1 : 0

  name        = "${local.name_prefix}-vpn-udp-500"
  project     = var.project_id
  region      = var.region
  ip_protocol = "UDP"
  port_range  = "500"
  ip_address  = google_compute_address.vpn_gateway[0].address
  target      = google_compute_vpn_gateway.classic[0].id
}

resource "google_compute_forwarding_rule" "vpn_udp_4500" {
  count = var.vpn_enabled ? 1 : 0

  name        = "${local.name_prefix}-vpn-udp-4500"
  project     = var.project_id
  region      = var.region
  ip_protocol = "UDP"
  port_range  = "4500"
  ip_address  = google_compute_address.vpn_gateway[0].address
  target      = google_compute_vpn_gateway.classic[0].id
}

resource "google_compute_vpn_tunnel" "static" {
  count = var.vpn_enabled ? 1 : 0

  name               = "${local.name_prefix}-vpn-tunnel"
  project            = var.project_id
  region             = var.region
  target_vpn_gateway = google_compute_vpn_gateway.classic[0].id
  peer_ip            = var.vpn_peer_ip
  shared_secret      = local.vpn_shared_secret_effective
  ike_version        = var.vpn_ike_version

  # Route-based Classic VPN. Las rutas efectivas se declaran con
  # google_compute_route, no por Cloud Router/BGP.
  local_traffic_selector  = ["0.0.0.0/0"]
  remote_traffic_selector = ["0.0.0.0/0"]

  depends_on = [
    google_compute_forwarding_rule.vpn_esp,
    google_compute_forwarding_rule.vpn_udp_500,
    google_compute_forwarding_rule.vpn_udp_4500,
  ]
}

resource "google_compute_route" "vpn_remote" {
  for_each = var.vpn_enabled ? toset(local.vpn_remote_cidrs_effective) : toset([])

  name                = "${local.name_prefix}-vpn-route-${replace(replace(each.value, ".", "-"), "/", "-")}"
  project             = var.project_id
  network             = module.network.vpc_self_link
  dest_range          = each.value
  priority            = 1000
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.static[0].id

  description = "Ruta estatica hacia ${each.value} por VPN on-premise"
}
