###############################################################################
# Módulo Load Balancer - HTTP(S) Global Load Balancer
# Proyecto: EDUFIS - WordPress en GCP
#
# Componentes:
#   - IP estática global
#   - Health check para el backend service
#   - Backend service con Cloud Armor
#   - URL map
#   - Certificado SSL gestionado por Google
#   - HTTP(S) proxy
#   - Forwarding rules (HTTP → HTTPS redirect + HTTPS)
###############################################################################

# ─── IP Estática Global ─────────────────────────────────────────────────────

resource "google_compute_global_address" "wordpress" {
  name        = "${var.name_prefix}-wordpress-ip"
  project     = var.project_id
  description = "IP estática global para el Load Balancer de WordPress"
}

# ─── Health Check para el Backend Service ────────────────────────────────────
# Health check del backend service

resource "google_compute_health_check" "wordpress_lb" {
  name                = "${var.name_prefix}-wordpress-lb-hc"
  project             = var.project_id
  description         = "Health check del Load Balancer para WordPress"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 80
    request_path = "/health"
  }

  log_config {
    enable = true
  }
}

# ─── Backend Service ─────────────────────────────────────────────────────────

resource "google_compute_backend_service" "wordpress" {
  name                  = "${var.name_prefix}-wordpress-backend"
  project               = var.project_id
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL_MANAGED"
  description           = "Backend service para WordPress con Cloud Armor"

  # Cloud Armor
  security_policy = var.cloud_armor_policy_self_link

  # Health check
  health_checks = [google_compute_health_check.wordpress_lb.id]

  # Backend: unmanaged instance group
  backend {
    group           = var.instance_group
    balancing_mode  = "UTILIZATION"
    max_utilization = 0.8
    capacity_scaler = 1.0
  }

  # Session affinity (opcional para WordPress)
  session_affinity = "GENERATED_COOKIE"

  # CDN deshabilitado mientras el acceso publico este cerrado por allowlist.
  # Con CDN habilitado, contenido cacheado puede servirse desde el edge.
  enable_cdn = false

  # Logging
  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# ─── URL Map ─────────────────────────────────────────────────────────────────

resource "google_compute_url_map" "wordpress" {
  name            = "${var.name_prefix}-wordpress-url-map"
  project         = var.project_id
  default_service = google_compute_backend_service.wordpress.id
  description     = "URL map para WordPress"
}

# URL Map para redirect HTTP → HTTPS
resource "google_compute_url_map" "wordpress_redirect" {
  name    = "${var.name_prefix}-wordpress-http-redirect"
  project = var.project_id

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }

  description = "Redirect HTTP a HTTPS para WordPress"
}

# ─── Certificado SSL Gestionado por Google ───────────────────────────────────

resource "google_compute_managed_ssl_certificate" "wordpress" {
  name    = "${var.name_prefix}-wordpress-ssl"
  project = var.project_id

  managed {
    domains = [var.domain]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ─── HTTPS Proxy ─────────────────────────────────────────────────────────────

resource "google_compute_target_https_proxy" "wordpress" {
  name             = "${var.name_prefix}-wordpress-https-proxy"
  project          = var.project_id
  url_map          = google_compute_url_map.wordpress.id
  ssl_certificates = [google_compute_managed_ssl_certificate.wordpress.id]

  # SSL policy (opcional - descomentar para política SSL estricta)
  # ssl_policy = google_compute_ssl_policy.wordpress.id
}

# ─── HTTP Proxy (para redirect a HTTPS) ─────────────────────────────────────

resource "google_compute_target_http_proxy" "wordpress_redirect" {
  name    = "${var.name_prefix}-wordpress-http-proxy"
  project = var.project_id
  url_map = google_compute_url_map.wordpress_redirect.id
}

# ─── Forwarding Rules ───────────────────────────────────────────────────────

# HTTPS (puerto 443) - Tráfico principal
resource "google_compute_global_forwarding_rule" "wordpress_https" {
  name                  = "${var.name_prefix}-wordpress-https-rule"
  project               = var.project_id
  target                = google_compute_target_https_proxy.wordpress.id
  port_range            = "443"
  ip_address            = google_compute_global_address.wordpress.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
  labels                = var.labels
}

# HTTP (puerto 80) - Redirect a HTTPS
resource "google_compute_global_forwarding_rule" "wordpress_http" {
  name                  = "${var.name_prefix}-wordpress-http-rule"
  project               = var.project_id
  target                = google_compute_target_http_proxy.wordpress_redirect.id
  port_range            = "80"
  ip_address            = google_compute_global_address.wordpress.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
  labels                = var.labels
}

# ─── SSL Policy (opcional) ──────────────────────────────────────────────────
# Descomentar para aplicar una política SSL estricta

# resource "google_compute_ssl_policy" "wordpress" {
#   name            = "${var.name_prefix}-wordpress-ssl-policy"
#   project         = var.project_id
#   profile         = "MODERN"
#   min_tls_version = "TLS_1_2"
# }
