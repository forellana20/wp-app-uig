###############################################################################
# Main - Orquestación de Módulos
# Proyecto: EDUFIS - WordPress en GCP
#
# Arquitectura:
#   Internet -> Cloud Armor -> LB HTTPS -> VM unica (WordPress+MySQL) -> Cloud NAT
#
# Módulos:
#   1. network       - VPC, Subred, Cloud Router, Cloud NAT
#   2. security      - Firewall, Cloud Armor, Service Account
#   3. compute       - VM unica y Unmanaged Instance Group
#   4. load-balancer - LB HTTP(S), SSL, IP Global, CDN
###############################################################################

# ─── Módulo: Network ─────────────────────────────────────────────────────────

module "network" {
  source = "./modules/network"

  name_prefix = local.name_prefix
  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  subnet_name = local.app_subnet_name
  subnet_cidr = local.app_subnet_cidr
  proxy_name  = local.proxy_subnet_name
  proxy_cidr  = local.proxy_subnet_cidr
  labels      = local.common_labels
}

# ─── Módulo: Security ────────────────────────────────────────────────────────

module "security" {
  source = "./modules/security"

  name_prefix                = local.name_prefix
  project_id                 = var.project_id
  vpc_id                     = module.network.vpc_id
  wordpress_tag              = local.wordpress_tag
  google_health_check_ranges = local.google_health_check_ranges
  google_iap_range           = local.google_iap_range
  vpn_cidr                   = var.vpn_cidr
  internal_proxy_subnet_cidr = local.proxy_subnet_cidr
  allowed_ip_ranges          = var.allowed_ip_ranges
  allowed_ip_rule_groups     = var.allowed_ip_rule_groups
  external_domain            = var.domain
  labels                     = local.common_labels

  depends_on = [module.network]
}

# ─── Permisos: lectura del bucket de WordPress ───────────────────────────────

resource "google_storage_bucket_iam_member" "wordpress_source_reader" {
  count = var.wordpress_source_bucket != "" ? 1 : 0

  bucket = var.wordpress_source_bucket
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${module.security.service_account_email}"

  depends_on = [module.security]
}

# ─── Secret Manager: contenedor del secreto MySQL ────────────────────────────

resource "google_project_service" "secret_manager" {
  project            = var.project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_secret_manager_secret" "wp_db_password" {
  project   = var.project_id
  secret_id = var.wp_db_password_secret_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.secret_manager]
}

# ─── Permisos: lectura del secreto de contraseña MySQL ───────────────────────

resource "google_secret_manager_secret_iam_member" "wp_db_password_accessor" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.wp_db_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.security.service_account_email}"

  depends_on = [module.security, google_secret_manager_secret.wp_db_password]
}

resource "google_secret_manager_secret_iam_member" "rhel_satellite_activation_key_accessor" {
  count = var.rhel_satellite_activation_key_secret_id != "" ? 1 : 0

  project   = var.project_id
  secret_id = var.rhel_satellite_activation_key_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.security.service_account_email}"

  depends_on = [module.security]
}

# ─── Módulo: Compute ─────────────────────────────────────────────────────────

module "compute" {
  source = "./modules/compute"

  name_prefix           = local.name_prefix
  project_id            = var.project_id
  region                = var.region
  zone                  = var.zone
  subnet_self_link      = module.network.subnet_self_link
  subnet_change_token   = module.network.subnet_self_link
  private_ip            = cidrhost(local.app_subnet_cidr, 2)
  service_account_email = module.security.service_account_email
  wordpress_tag         = local.wordpress_tag

  # Configuración de la instancia
  machine_type      = var.machine_type
  boot_disk_size_gb = var.boot_disk_size_gb
  boot_disk_type    = var.boot_disk_type
  image_family      = var.image_family
  image_project     = var.image_project

  # Startup script renderizado con variables
  startup_script = templatefile("${path.module}/scripts/startup.sh", {
    project_id                         = var.project_id
    db_name                            = var.wp_db_name
    db_user                            = var.wp_db_user
    db_password_secret_id              = var.wp_db_password_secret_id
    wp_admin_email                     = var.wp_admin_email
    wp_domain                          = var.domain
    wp_table_prefix                    = var.wp_table_prefix
    wp_source_url                      = var.wp_source_url
    wp_target_url                      = var.wp_target_url
    wordpress_source_gcs_uri           = var.wordpress_source_gcs_uri
    wordpress_db_dump_gcs_uri          = var.wordpress_db_dump_gcs_uri
    satellite_server_url               = var.rhel_satellite_server_url
    satellite_org                      = var.rhel_satellite_org
    satellite_activation_key_secret_id = var.rhel_satellite_activation_key_secret_id
    gcs_access_dependency              = var.wordpress_source_bucket != "" ? google_storage_bucket_iam_member.wordpress_source_reader[0].role : ""
    secret_access_dependency           = google_secret_manager_secret_iam_member.wp_db_password_accessor.role
  })

  labels = local.common_labels

  depends_on = [
    module.network,
    module.security,
    google_storage_bucket_iam_member.wordpress_source_reader,
    google_secret_manager_secret_iam_member.wp_db_password_accessor,
    google_secret_manager_secret_iam_member.rhel_satellite_activation_key_accessor,
  ]
}

# ─── Módulo: Load Balancer ───────────────────────────────────────────────────

module "load_balancer" {
  source = "./modules/load-balancer"

  name_prefix                  = local.name_prefix
  project_id                   = var.project_id
  region                       = var.region
  network_self_link            = module.network.vpc_self_link
  subnet_self_link             = module.network.subnet_self_link
  instance_group               = module.compute.instance_group_self_link
  cloud_armor_policy_self_link = module.security.cloud_armor_policy_self_link
  domain                       = var.domain
  internal_domain              = var.internal_domain
  labels                       = local.common_labels

  depends_on = [module.compute, module.security]
}
