###############################################################################
# Variables - Módulo Security
###############################################################################

variable "name_prefix" {
  description = "Prefijo para nombrar recursos"
  type        = string
}

variable "project_id" {
  description = "ID del proyecto en GCP"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC"
  type        = string
}

variable "wordpress_tag" {
  description = "Tag de red para instancias de WordPress"
  type        = string
}

variable "google_health_check_ranges" {
  description = "Rangos de IP de Google para health checks"
  type        = list(string)
}

variable "google_iap_range" {
  description = "Rango de IP de Google IAP para SSH"
  type        = string
}

variable "vpn_cidr" {
  description = "CIDR de la red VPN"
  type        = string
  default     = ""
}

variable "internal_proxy_subnet_cidr" {
  description = "CIDR de la proxy-only subnet del Internal/Regional Managed Load Balancer"
  type        = string
  default     = ""
}

variable "allowed_ip_ranges" {
  description = "Rangos de IP permitidos para Cloud Armor"
  type        = list(string)
  default     = []
}

variable "allowed_ip_rule_groups" {
  description = "Grupos adicionales de IPs permitidas para Cloud Armor."
  type = list(object({
    priority    = number
    description = string
    ip_ranges   = list(string)
  }))
  default = []
}

variable "external_domain" {
  description = "Dominio publico esperado en el Host header del Load Balancer externo"
  type        = string
}

variable "labels" {
  description = "Etiquetas comunes"
  type        = map(string)
  default     = {}
}
