###############################################################################
# Backend Remoto - Google Cloud Storage
# Proyecto: EDUFIS - WordPress en GCP
#
# INSTRUCCIONES:
# 1. Crear el bucket de estado antes de inicializar:
#    gsutil mb -p proy-infra-desa03-edufi-wp -l us-east1 gs://proy-infra-desa03-edufi-wp-terraform-state
#    gsutil versioning set on gs://proy-infra-desa03-edufi-wp-terraform-state
#
# 2. Descomentar el bloque backend y reemplazar los valores
# 3. Ejecutar: terraform init -migrate-state
###############################################################################

terraform {
  backend "gcs" {
    bucket                      = "proy-infra-desa03-edufi-wp-terraform-state"
    prefix                      = "wordpress/dev"
    impersonate_service_account = "terraform-deployer@proy-infra-desa03-edufi-wp.iam.gserviceaccount.com"
  }
}
