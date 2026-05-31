###############################################################################
# Variables - Módulo Network
###############################################################################

variable "name_prefix" {
  description = "Prefijo para nombrar recursos"
  type        = string
}

variable "project_id" {
  description = "ID del proyecto en GCP"
  type        = string
}

variable "region" {
  description = "Región de despliegue"
  type        = string
}

variable "environment" {
  description = "Ambiente de despliegue (dev o prod)"
  type        = string
}

variable "subnet_name" {
  description = "Nombre de la subred de aplicación"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR de la subred de aplicación"
  type        = string
}

variable "proxy_name" {
  description = "Nombre de la proxy-only subnet"
  type        = string
}

variable "proxy_cidr" {
  description = "CIDR de la proxy-only subnet para Internal/Regional Managed LB"
  type        = string
}

variable "labels" {
  description = "Etiquetas comunes"
  type        = map(string)
  default     = {}
}
