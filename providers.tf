###############################################################################
# Configuración de Providers
# Proyecto: EDUFIS - WordPress en GCP
###############################################################################

provider "google" {
  project                     = var.project_id
  region                      = var.region
  impersonate_service_account = var.terraform_impersonate_service_account
}

provider "google-beta" {
  project                     = var.project_id
  region                      = var.region
  impersonate_service_account = var.terraform_impersonate_service_account
}
