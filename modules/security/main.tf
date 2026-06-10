###############################################################################
# Módulo Security - Firewall, Cloud Armor, Service Account
# Proyecto: EDUFIS - WordPress en GCP
#
# Componentes:
#   - Service Account dedicado para WordPress (mínimos privilegios)
#   - Reglas de Firewall restrictivas
#   - Cloud Armor security policy
###############################################################################

# ─── Service Account ─────────────────────────────────────────────────────────
# Cuenta de servicio dedicada con permisos mínimos para las VMs de WordPress

resource "google_service_account" "wordpress" {
  account_id   = "${var.name_prefix}-wordpress-sa"
  display_name = "WordPress Service Account - ${var.name_prefix}"
  project      = var.project_id
  description  = "Cuenta de servicio para instancias de WordPress con permisos mínimos"
}

# Permisos mínimos: solo logging y monitoring
resource "google_project_iam_member" "wordpress_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.wordpress.email}"
}

resource "google_project_iam_member" "wordpress_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.wordpress.email}"
}

# Permiso para leer metadata de las instancias
resource "google_project_iam_member" "wordpress_metadata_reader" {
  project = var.project_id
  role    = "roles/compute.viewer"
  member  = "serviceAccount:${google_service_account.wordpress.email}"
}

# ─── Firewall Rules ──────────────────────────────────────────────────────────

# Regla: Permitir HTTP/HTTPS desde el Load Balancer (health checks + tráfico)
resource "google_compute_firewall" "allow_lb_health_check" {
  name    = "${var.name_prefix}-allow-lb-health-check"
  project = var.project_id
  network = var.vpc_id

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = var.google_health_check_ranges
  target_tags   = [var.wordpress_tag]
  direction     = "INGRESS"
  priority      = 1000

  description = "Permitir tráfico HTTP/HTTPS desde Google Load Balancer y health checks"

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Regla: Permitir SSH solo desde IAP (Identity-Aware Proxy)
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "${var.name_prefix}-allow-iap-ssh"
  project = var.project_id
  network = var.vpc_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [var.google_iap_range]
  target_tags   = [var.wordpress_tag]
  direction     = "INGRESS"
  priority      = 1100

  description = "Permitir SSH solo desde Google IAP (acceso seguro sin IP pública)"

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Regla: Permitir SSH desde VPN (si se configura)
resource "google_compute_firewall" "allow_vpn_ssh" {
  count   = var.vpn_cidr != "" ? 1 : 0
  name    = "${var.name_prefix}-allow-vpn-ssh"
  project = var.project_id
  network = var.vpc_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [var.vpn_cidr]
  target_tags   = [var.wordpress_tag]
  direction     = "INGRESS"
  priority      = 1200

  description = "Permitir SSH desde la VPN corporativa"

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Regla: Permitir tráfico desde los proxies del Internal Application Load Balancer
resource "google_compute_firewall" "allow_internal_lb_proxy" {
  count   = var.internal_proxy_subnet_cidr != "" ? 1 : 0
  name    = "${var.name_prefix}-allow-internal-lb-proxy"
  project = var.project_id
  network = var.vpc_id

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = [var.internal_proxy_subnet_cidr]
  target_tags   = [var.wordpress_tag]
  direction     = "INGRESS"
  priority      = 1050

  description = "Permitir HTTP desde la proxy-only subnet del Internal Application Load Balancer"

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Regla: Permitir ICMP interno (para diagnósticos)
resource "google_compute_firewall" "allow_internal_icmp" {
  name    = "${var.name_prefix}-allow-internal-icmp"
  project = var.project_id
  network = var.vpc_id

  allow {
    protocol = "icmp"
  }

  source_tags = [var.wordpress_tag]
  target_tags = [var.wordpress_tag]
  direction   = "INGRESS"
  priority    = 1300

  description = "Permitir ICMP entre instancias de WordPress para diagnósticos"
}

# Regla: Denegar todo el tráfico de entrada (catch-all explícito)
resource "google_compute_firewall" "deny_all_ingress" {
  name    = "${var.name_prefix}-deny-all-ingress"
  project = var.project_id
  network = var.vpc_id

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
  direction     = "INGRESS"
  priority      = 65534

  description = "Denegar todo el tráfico de entrada no permitido explícitamente"

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# ─── Cloud Armor Security Policy ────────────────────────────────────────────
# Protección WAF contra ataques comunes

resource "google_compute_security_policy" "wordpress" {
  name        = "${var.name_prefix}-cloud-armor"
  project     = var.project_id
  description = "Cloud Armor policy para proteger WordPress"

  # Regla por defecto: denegar todo el tráfico
  rule {
    action   = "deny(403)"
    priority = "2147483647"

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }

    description = "Regla por defecto - denegar tráfico"
  }

  # Regla: bloquear accesos por IP directa u otros host headers.
  rule {
    action   = "deny(403)"
    priority = "700"

    match {
      expr {
        expression = "!has(request.headers['host']) || request.headers['host'] != '${var.external_domain}'"
      }
    }

    description = "Bloquear accesos sin dominio publico valido"
  }

  # Regla: Permitir explícitamente todo el portal desde IPs autorizadas.
  dynamic "rule" {
    for_each = length(var.allowed_ip_ranges) > 0 ? [1] : []

    content {
      action   = "allow"
      priority = "5000"

      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = var.allowed_ip_ranges
        }
      }

      description = "Permitir acceso al portal desde IPs autorizadas"
    }
  }

  # Reglas adicionales: grupos de IPs publicas del cliente.
  dynamic "rule" {
    for_each = {
      for group in var.allowed_ip_rule_groups : tostring(group.priority) => group
    }

    content {
      action   = "allow"
      priority = rule.value.priority

      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = rule.value.ip_ranges
        }
      }

      description = rule.value.description
    }
  }

  # Regla: Bloquear SQL Injection (SQLi)
  rule {
    action   = "deny(403)"
    priority = "1000"

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-v33-stable')"
      }
    }

    description = "Bloquear ataques de SQL Injection"
  }

  # Regla: Bloquear Cross-Site Scripting (XSS)
  rule {
    action   = "deny(403)"
    priority = "1001"

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-v33-stable')"
      }
    }

    description = "Bloquear ataques de Cross-Site Scripting (XSS)"
  }

  # Regla: Bloquear Local File Inclusion (LFI)
  rule {
    action   = "deny(403)"
    priority = "1002"

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('lfi-v33-stable')"
      }
    }

    description = "Bloquear ataques de Local File Inclusion (LFI)"
  }

  # Regla: Bloquear Remote File Inclusion (RFI)
  rule {
    action   = "deny(403)"
    priority = "1003"

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rfi-v33-stable')"
      }
    }

    description = "Bloquear ataques de Remote File Inclusion (RFI)"
  }

  # Regla: Bloquear acceso a wp-login desde IPs no autorizadas
  # Descomentar y ajustar según necesidad
  # rule {
  #   action   = "deny(403)"
  #   priority = "900"
  #
  #   match {
  #     expr {
  #       expression = "request.path.matches('/wp-login.php') && !inIpRange(origin.ip, '10.130.20.0/24')"
  #     }
  #   }
  #
  #   description = "Restringir wp-login solo a IPs de VPN"
  # }

  # No agregar reglas throttle globales en modo allowlist. En Cloud Armor,
  # conform_action = "allow" permitiria trafico publico antes del default deny.
}
