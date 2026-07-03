###############################################################################
# Variables Globales
# Proyecto: EDUFIS - WordPress en GCP
###############################################################################

# ─── Proyecto y Región ───────────────────────────────────────────────────────

variable "project_id" {
  description = "ID del proyecto en GCP"
  type        = string
}

variable "terraform_impersonate_service_account" {
  description = "Service account que Terraform impersona para crear recursos"
  type        = string
  default     = null
}

variable "region" {
  description = "Región principal de despliegue"
  type        = string
  default     = "us-east1"
}

variable "zone" {
  description = "Zona principal (para recursos zonales)"
  type        = string
  default     = "us-east1-b"
}

# ─── Nomenclatura ────────────────────────────────────────────────────────────

variable "prefix" {
  description = "Prefijo para nombrar todos los recursos (ej: edufis)"
  type        = string
  default     = "edufis"
}

variable "environment" {
  description = "Ambiente de despliegue (dev, staging, prod)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "El ambiente debe ser: dev o prod."
  }
}

# ─── Networking ──────────────────────────────────────────────────────────────

variable "subnet_cidr" {
  description = "CIDR de la subred de aplicación. Si es null, se usa el rango aprobado para el ambiente."
  type        = string
  default     = null

  validation {
    condition     = var.subnet_cidr == null || can(cidrhost(var.subnet_cidr, 0))
    error_message = "subnet_cidr debe ser un CIDR válido o null."
  }
}

variable "vpn_cidr" {
  description = "CIDR on-premise autorizado para SSH por VPN. Dejar vacio para usar solo IAP."
  type        = string
  default     = ""
}

variable "vpn_enabled" {
  description = "Habilita la VPN site-to-site clasica con rutas estaticas hacia on-premise."
  type        = bool
  default     = false
}

variable "vpn_peer_ip" {
  description = "IP publica del gateway VPN on-premise del cliente."
  type        = string
  default     = ""
}

variable "vpn_remote_cidrs" {
  description = "Rangos on-premise alcanzables por la VPN estatica, incluyendo Satellite si aplica."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.vpn_remote_cidrs : can(cidrhost(cidr, 0))])
    error_message = "Todos los valores de vpn_remote_cidrs deben ser CIDR validos."
  }
}

variable "vpn_shared_secret" {
  description = "Pre-shared key opcional. Si queda vacia, Terraform genera una y la mantiene en el state."
  type        = string
  default     = ""
  sensitive   = true
}

variable "vpn_ike_version" {
  description = "Version IKE del tunel VPN."
  type        = number
  default     = 2

  validation {
    condition     = contains([1, 2], var.vpn_ike_version)
    error_message = "vpn_ike_version debe ser 1 o 2."
  }
}

# ─── Compute ─────────────────────────────────────────────────────────────────

variable "machine_type" {
  description = "Tipo de máquina para las instancias de WordPress"
  type        = string
  default     = "e2-medium"
}

variable "boot_disk_size_gb" {
  description = "Tamaño del disco de arranque en GB"
  type        = number
  default     = 50
}

variable "boot_disk_type" {
  description = "Tipo de disco de arranque (pd-standard, pd-balanced, pd-ssd)"
  type        = string
  default     = "pd-balanced"
}

variable "image_family" {
  description = "Familia de imagen del SO base"
  type        = string
  default     = "rhel-9"
}

variable "image_project" {
  description = "Proyecto de la imagen del SO"
  type        = string
  default     = "rhel-byos-cloud"
}

variable "rhel_satellite_server_url" {
  description = "URL del Red Hat Satellite o Capsule del cliente para registrar RHEL. Ej: https://satellite.example.com"
  type        = string
  default     = ""
}

variable "rhel_satellite_org" {
  description = "Organizacion de Red Hat Satellite usada para registrar la VM."
  type        = string
  default     = ""
}

variable "rhel_satellite_activation_key_secret_id" {
  description = "ID del secreto en Secret Manager que contiene la activation key de Red Hat Satellite."
  type        = string
  default     = ""
}

# ─── WordPress / Base de datos ───────────────────────────────────────────────

variable "wp_db_name" {
  description = "Nombre de la base de datos de WordPress"
  type        = string
  default     = "wordpress_db"
}

variable "wp_db_user" {
  description = "Usuario de la base de datos de WordPress"
  type        = string
  default     = "wp_user"
}

variable "wp_db_password_secret_id" {
  description = "ID del secreto de Secret Manager que contiene la contraseña de la base de datos de WordPress."
  type        = string
}

variable "wp_admin_email" {
  description = "Email del administrador de WordPress"
  type        = string
  default     = "admin@example.com"
}

variable "wp_table_prefix" {
  description = "Prefijo de tablas de WordPress. Debe coincidir con el dump SQL migrado."
  type        = string
  default     = "wp_"
}

variable "wp_source_url" {
  description = "URL original del WordPress migrado para reemplazarla en la base de datos."
  type        = string
  default     = ""
}

variable "wp_target_url" {
  description = "URL destino de WordPress. Si queda vacía se usa https://<domain>."
  type        = string
  default     = ""
}

variable "wordpress_source_bucket" {
  description = "Bucket existente desde donde la VM puede leer archivos de WordPress y dumps. Vacío deshabilita el IAM automático."
  type        = string
  default     = ""
}

variable "wordpress_source_gcs_uri" {
  description = "URI GCS del WordPress a instalar. Puede ser un ZIP o un prefijo, por ejemplo gs://bucket/wordpress/."
  type        = string
  default     = ""
}

variable "wordpress_db_dump_gcs_uri" {
  description = "URI GCS opcional del dump SQL a importar en la base de datos local."
  type        = string
  default     = ""
}

# ─── SSL / Dominio ───────────────────────────────────────────────────────────

variable "domain" {
  description = "Dominio para el certificado SSL gestionado por Google"
  type        = string
  default     = "edufis.example.com"
}

variable "public_dns_managed_zone" {
  description = "Nombre de la zona Cloud DNS pública/autoritativa donde se creará el registro A externo. Vacío deshabilita la creación automática."
  type        = string
  default     = ""
}

# ─── Cloud Armor ─────────────────────────────────────────────────────────────

variable "allowed_ip_ranges" {
  description = "Rangos de IP permitidos para acceso administrativo (CIDR)"
  type        = list(string)
  default     = []
}

variable "allowed_ip_rule_groups" {
  description = "Grupos adicionales de IPs permitidas en Cloud Armor."
  type = list(object({
    priority    = number
    description = string
    ip_ranges   = list(string)
  }))
  default = []
}

# ─── Etiquetas ───────────────────────────────────────────────────────────────

variable "labels" {
  description = "Etiquetas comunes para todos los recursos"
  type        = map(string)
  default     = {}
}
