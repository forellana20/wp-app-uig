###############################################################################
# Outputs - Información Crítica del Despliegue
# Proyecto: EDUFIS - WordPress en GCP
###############################################################################

# ─── Network ─────────────────────────────────────────────────────────────────

output "vpc_name" {
  description = "Nombre de la VPC"
  value       = module.network.vpc_name
}

output "subnet_name" {
  description = "Nombre de la subred de aplicación"
  value       = module.network.subnet_name
}

output "subnet_cidr" {
  description = "CIDR de la subred de aplicación"
  value       = module.network.subnet_cidr
}

output "proxy_subnet_name" {
  description = "Nombre de la proxy-only subnet"
  value       = module.network.proxy_subnet_name
}

output "proxy_subnet_cidr" {
  description = "CIDR de la proxy-only subnet"
  value       = module.network.proxy_subnet_cidr
}

# ─── Load Balancer ───────────────────────────────────────────────────────────

output "load_balancer_ip" {
  description = "IP pública del Load Balancer (apuntar DNS aquí)"
  value       = module.load_balancer.global_ip_address
}

output "wordpress_url" {
  description = "URL de acceso a WordPress"
  value       = module.load_balancer.wordpress_url
}

output "internal_load_balancer_ip" {
  description = "IP privada del Internal Application Load Balancer"
  value       = module.load_balancer.internal_ip_address
}

output "internal_wordpress_url" {
  description = "URL interna de acceso a WordPress"
  value       = module.load_balancer.internal_wordpress_url
}

# ─── Compute ─────────────────────────────────────────────────────────────────

output "wordpress_instance_name" {
  description = "Nombre de la VM de WordPress"
  value       = module.compute.instance_name
}

output "wordpress_instance_internal_ip" {
  description = "IP interna de la VM de WordPress"
  value       = module.compute.instance_internal_ip
}

output "instance_group_self_link" {
  description = "Self link del unmanaged instance group"
  value       = module.compute.instance_group_self_link
}

# ─── Security ────────────────────────────────────────────────────────────────

output "service_account_email" {
  description = "Email del Service Account de WordPress"
  value       = module.security.service_account_email
}

output "cloud_armor_policy_id" {
  description = "ID de la política de Cloud Armor"
  value       = module.security.cloud_armor_policy_id
}

# ─── DNS Instructions ────────────────────────────────────────────────────────

output "dns_instructions" {
  description = "Instrucciones para configurar DNS"
  value       = <<-EOT

    ╔══════════════════════════════════════════════════════════════════╗
    ║                    CONFIGURACIÓN DNS                           ║
    ╠══════════════════════════════════════════════════════════════════╣
    ║                                                                 ║
    ║  Crear un registro DNS tipo A:                                  ║
    ║                                                                 ║
    ║  Nombre:  ${var.domain}
    ║  Tipo:    A                                                     ║
    ║  Valor:   ${module.load_balancer.global_ip_address}
    ║  TTL:     300                                                   ║
    ║                                                                 ║
    ║  El certificado SSL se provisionará automáticamente             ║
    ║  una vez que el DNS apunte a la IP del Load Balancer.           ║
    ║  Esto puede tomar entre 15-60 minutos.                         ║
    ║                                                                 ║
    ╚══════════════════════════════════════════════════════════════════╝
  EOT
}

output "internal_dns_instructions" {
  description = "Instrucciones para configurar DNS interno y autorización del certificado interno"
  value = var.internal_domain != "" ? (
    <<-EOT

    ╔══════════════════════════════════════════════════════════════════╗
    ║             CONFIGURACIÓN DNS INTERNA / CERTIFICADO            ║
    ╠══════════════════════════════════════════════════════════════════╣
    ║                                                                 ║
    ║  Registro A interno para el acceso privado:                     ║
    ║                                                                 ║
    ║  Nombre:  ${var.internal_domain}
    ║  Tipo:    A                                                     ║
    ║  Valor:   ${module.load_balancer.internal_ip_address}
    ║  TTL:     300                                                   ║
    ║                                                                 ║
    ║  Registro CNAME para autorizar el certificado Google-managed:   ║
    ║                                                                 ║
    ║  Nombre:  ${module.load_balancer.internal_dns_authorization_record_name}
    ║  Tipo:    ${module.load_balancer.internal_dns_authorization_record_type}
    ║  Valor:   ${module.load_balancer.internal_dns_authorization_record_data}
    ║                                                                 ║
    ║  El certificado interno se emitirá cuando el CNAME de           ║
    ║  autorización resuelva correctamente en el DNS autoritativo     ║
    ║  consultable por Google. El registro A interno puede vivir en   ║
    ║  DNS privado, pero el CNAME de validación debe ser visible      ║
    ║  para Certificate Manager.                                      ║
    ║                                                                 ║
    ╚══════════════════════════════════════════════════════════════════╝
  EOT
  ) : ""
}

output "cloud_dns_records_managed_by_terraform" {
  description = "Resumen de registros DNS que Terraform administra en Cloud DNS. Si está vacío, el DNS debe gestionarse fuera de Terraform."
  value = {
    external_a = var.public_dns_managed_zone != "" ? {
      zone  = var.public_dns_managed_zone
      name  = local.external_dns_name
      type  = "A"
      value = module.load_balancer.global_ip_address
    } : null

    internal_a = var.internal_domain != "" && var.internal_dns_managed_zone != "" ? {
      zone  = var.internal_dns_managed_zone
      name  = local.internal_dns_name
      type  = "A"
      value = module.load_balancer.internal_ip_address
    } : null

    internal_certificate_cname = var.internal_domain != "" && local.certificate_dns_authorization_zone != "" ? {
      zone  = local.certificate_dns_authorization_zone
      name  = module.load_balancer.internal_dns_authorization_record_name
      type  = module.load_balancer.internal_dns_authorization_record_type
      value = module.load_balancer.internal_dns_authorization_record_data
    } : null
  }
}

# ─── SSH Instructions ────────────────────────────────────────────────────────

output "ssh_instructions" {
  description = "Instrucciones para acceso SSH via IAP"
  value       = <<-EOT

    Para conectarse por SSH a la VM via IAP:

    gcloud compute ssh ${module.compute.instance_name} \
      --project=${var.project_id} \
      --zone=${var.zone} \
      --tunnel-through-iap

    Para consultar el unmanaged instance group:

    gcloud compute instance-groups unmanaged list-instances \
      ${local.name_prefix}-wordpress-ig \
      --project=${var.project_id} \
      --zone=${var.zone}
  EOT
}
