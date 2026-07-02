###############################################################################
# Variables - Módulo Load Balancer
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

variable "instance_group" {
  description = "URL del instance group backend"
  type        = string
}

variable "cloud_armor_policy_self_link" {
  description = "Self link de la política de Cloud Armor"
  type        = string
}

variable "domain" {
  description = "Dominio para el certificado SSL"
  type        = string
}

variable "labels" {
  description = "Etiquetas comunes"
  type        = map(string)
  default     = {}
}
