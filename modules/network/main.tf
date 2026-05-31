###############################################################################
# Módulo Network - VPC, Subred, Cloud Router, Cloud NAT
# Proyecto: EDUFIS - WordPress en GCP
#
# Componentes:
#   - VPC en modo custom (sin subredes automáticas)
#   - Subred de aplicación para WordPress
#   - Proxy-only subnet reservada para un futuro Internal/Regional Managed LB
#   - Cloud Router para enrutamiento dinámico
#   - Cloud NAT para salida a internet de las VMs (sin IP pública)
###############################################################################

# ─── VPC ─────────────────────────────────────────────────────────────────────

resource "google_compute_network" "vpc" {
  name                    = "${var.name_prefix}-vpc"
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  description             = "VPC principal para WordPress - ${var.name_prefix}"
}

# ─── Subred de Aplicación ────────────────────────────────────────────────────

resource "google_compute_subnetwork" "wordpress" {
  name                     = var.subnet_name
  project                  = var.project_id
  region                   = var.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }

  description = "Subred para VM de WordPress - ${var.environment}"
}

# ─── Proxy-only Subnet ───────────────────────────────────────────────────────
# Requerida por load balancers regionales managed, incluyendo Internal HTTP(S) LB.
# El load balancer externo global actual no la consume, pero se reserva el rango
# aprobado para evitar solapes cuando se agregue el acceso interno.

resource "google_compute_subnetwork" "proxy" {
  name          = var.proxy_name
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = var.proxy_cidr
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"

  description = "Proxy-only subnet para Internal/Regional Managed LB - ${var.environment}"
}

# ─── Cloud Router ────────────────────────────────────────────────────────────

resource "google_compute_router" "router" {
  name    = "${var.name_prefix}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.vpc.id

  bgp {
    asn = 64514
  }

  description = "Cloud Router para NAT gateway"
}

# ─── Cloud NAT ───────────────────────────────────────────────────────────────
# Permite a las VMs sin IP pública acceder a internet (actualizaciones, paquetes)

resource "google_compute_router_nat" "nat" {
  name                               = "${var.name_prefix}-nat"
  project                            = var.project_id
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.wordpress.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }

  # Timeouts para conexiones NAT
  min_ports_per_vm                 = 64
  tcp_established_idle_timeout_sec = 1200
  tcp_transitory_idle_timeout_sec  = 30
  tcp_time_wait_timeout_sec        = 120
  udp_idle_timeout_sec             = 30
  icmp_idle_timeout_sec            = 30
}
