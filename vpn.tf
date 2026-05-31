###############################################################################
# VPN Configuration (OPCIONAL - Descomentar según necesidad)
# Proyecto: EDUFIS - WordPress en GCP
#
# Este archivo contiene la configuración para establecer una VPN
# entre la red on-premise y GCP. Descomentar y ajustar los valores
# según la configuración de su red corporativa.
#
# Prerequisitos:
#   - IP pública del gateway VPN on-premise
#   - Pre-shared key acordada
#   - CIDR de la red on-premise
#   - Cloud Router ya creado (módulo network)
###############################################################################

# ─── Variables adicionales para VPN ──────────────────────────────────────────

# variable "vpn_peer_ip" {
#   description = "IP pública del gateway VPN on-premise"
#   type        = string
# }
#
# variable "vpn_shared_secret" {
#   description = "Secreto compartido para el túnel VPN"
#   type        = string
#   sensitive   = true
# }
#
# variable "vpn_peer_asn" {
#   description = "ASN del peer BGP (on-premise)"
#   type        = number
#   default     = 65515
# }

# ─── VPN Gateway ─────────────────────────────────────────────────────────────

# resource "google_compute_ha_vpn_gateway" "vpn_gateway" {
#   name    = "${local.name_prefix}-vpn-gateway"
#   project = var.project_id
#   region  = var.region
#   network = module.network.vpc_id
# }

# ─── Peer VPN Gateway (On-Premise) ──────────────────────────────────────────

# resource "google_compute_external_vpn_gateway" "peer_gateway" {
#   name            = "${local.name_prefix}-peer-vpn-gateway"
#   project         = var.project_id
#   redundancy_type = "SINGLE_IP_INTERNALLY_REDUNDANT"
#   description     = "Gateway VPN on-premise"
#
#   interface {
#     id         = 0
#     ip_address = var.vpn_peer_ip
#   }
# }

# ─── VPN Tunnel ──────────────────────────────────────────────────────────────

# resource "google_compute_vpn_tunnel" "tunnel_0" {
#   name                            = "${local.name_prefix}-vpn-tunnel-0"
#   project                         = var.project_id
#   region                          = var.region
#   vpn_gateway                     = google_compute_ha_vpn_gateway.vpn_gateway.id
#   vpn_gateway_interface           = 0
#   peer_external_gateway           = google_compute_external_vpn_gateway.peer_gateway.id
#   peer_external_gateway_interface = 0
#   shared_secret                   = var.vpn_shared_secret
#   router                          = module.network.router_name
#   ike_version                     = 2
# }
#
# resource "google_compute_vpn_tunnel" "tunnel_1" {
#   name                            = "${local.name_prefix}-vpn-tunnel-1"
#   project                         = var.project_id
#   region                          = var.region
#   vpn_gateway                     = google_compute_ha_vpn_gateway.vpn_gateway.id
#   vpn_gateway_interface           = 1
#   peer_external_gateway           = google_compute_external_vpn_gateway.peer_gateway.id
#   peer_external_gateway_interface = 0
#   shared_secret                   = var.vpn_shared_secret
#   router                          = module.network.router_name
#   ike_version                     = 2
# }

# ─── Router Interfaces y BGP Peers ──────────────────────────────────────────

# resource "google_compute_router_interface" "vpn_interface_0" {
#   name       = "${local.name_prefix}-vpn-interface-0"
#   project    = var.project_id
#   router     = module.network.router_name
#   region     = var.region
#   ip_range   = "169.254.0.1/30"
#   vpn_tunnel = google_compute_vpn_tunnel.tunnel_0.name
# }
#
# resource "google_compute_router_interface" "vpn_interface_1" {
#   name       = "${local.name_prefix}-vpn-interface-1"
#   project    = var.project_id
#   router     = module.network.router_name
#   region     = var.region
#   ip_range   = "169.254.1.1/30"
#   vpn_tunnel = google_compute_vpn_tunnel.tunnel_1.name
# }
#
# resource "google_compute_router_peer" "vpn_peer_0" {
#   name                      = "${local.name_prefix}-vpn-peer-0"
#   project                   = var.project_id
#   router                    = module.network.router_name
#   region                    = var.region
#   peer_ip_address           = "169.254.0.2"
#   peer_asn                  = var.vpn_peer_asn
#   advertised_route_priority = 100
#   interface                 = google_compute_router_interface.vpn_interface_0.name
# }
#
# resource "google_compute_router_peer" "vpn_peer_1" {
#   name                      = "${local.name_prefix}-vpn-peer-1"
#   project                   = var.project_id
#   router                    = module.network.router_name
#   region                    = var.region
#   peer_ip_address           = "169.254.1.2"
#   peer_asn                  = var.vpn_peer_asn
#   advertised_route_priority = 100
#   interface                 = google_compute_router_interface.vpn_interface_1.name
# }
