###############################################################################
# Variables - Módulo Compute
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

variable "zone" {
  description = "Zona principal"
  type        = string
}

variable "subnet_self_link" {
  description = "Self link de la subred"
  type        = string
}

variable "subnet_change_token" {
  description = "Token para forzar reemplazo de la VM cuando cambia la subred"
  type        = string
}

variable "private_ip" {
  description = "IP privada fija para la VM dentro de la subred de aplicación"
  type        = string
}

variable "service_account_email" {
  description = "Email del service account para las instancias"
  type        = string
}

variable "wordpress_tag" {
  description = "Tag de red para instancias de WordPress"
  type        = string
}

variable "machine_type" {
  description = "Tipo de máquina"
  type        = string
}

variable "boot_disk_size_gb" {
  description = "Tamaño del disco de arranque en GB"
  type        = number
}

variable "boot_disk_type" {
  description = "Tipo de disco de arranque"
  type        = string
}

variable "image_family" {
  description = "Familia de imagen del SO"
  type        = string
}

variable "image_project" {
  description = "Proyecto de la imagen del SO"
  type        = string
}

variable "startup_script" {
  description = "Script de inicio renderizado"
  type        = string
}

variable "labels" {
  description = "Etiquetas comunes"
  type        = map(string)
  default     = {}
}
