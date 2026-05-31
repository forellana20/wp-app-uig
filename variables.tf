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

variable "proxy_subnet_cidr" {
  description = "CIDR de la proxy-only subnet para un futuro Internal/Regional Managed LB. Si es null, se usa el rango aprobado para el ambiente."
  type        = string
  default     = null

  validation {
    condition     = var.proxy_subnet_cidr == null || can(cidrhost(var.proxy_subnet_cidr, 0))
    error_message = "proxy_subnet_cidr debe ser un CIDR válido o null."
  }
}

variable "vpn_cidr" {
  description = "CIDR de la red VPN (oficinas/on-premise)"
  type        = string
  default     = "10.130.20.0/24"
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
  default     = "ubuntu-2204-lts"
}

variable "image_project" {
  description = "Proyecto de la imagen del SO"
  type        = string
  default     = "ubuntu-os-cloud"
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

variable "internal_domain" {
  description = "Dominio interno para el Internal Application Load Balancer. Si queda vacío, no se crea el LB interno."
  type        = string
  default     = ""
}

variable "public_dns_managed_zone" {
  description = "Nombre de la zona Cloud DNS pública/autoritativa donde se creará el registro A externo. Vacío deshabilita la creación automática."
  type        = string
  default     = ""
}

variable "internal_dns_managed_zone" {
  description = "Nombre de la zona Cloud DNS privada donde se creará el registro A interno. Vacío deshabilita la creación automática."
  type        = string
  default     = ""
}

variable "certificate_dns_authorization_managed_zone" {
  description = "Nombre de la zona Cloud DNS autoritativa donde se creará el CNAME de autorización del certificado interno. Si queda vacío y public_dns_managed_zone está definido, se usará public_dns_managed_zone."
  type        = string
  default     = ""
}

# ─── Cloud Armor ─────────────────────────────────────────────────────────────

variable "allowed_ip_ranges" {
  description = "Rangos de IP permitidos para acceso administrativo (CIDR)"
  type        = list(string)
  default     = []
}

# ─── Etiquetas ───────────────────────────────────────────────────────────────

variable "labels" {
  description = "Etiquetas comunes para todos los recursos"
  type        = map(string)
  default     = {}
}
