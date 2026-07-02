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

# ─── Load Balancer ───────────────────────────────────────────────────────────

output "load_balancer_ip" {
  description = "IP pública del Load Balancer (apuntar DNS aquí)"
  value       = module.load_balancer.global_ip_address
}

output "wordpress_url" {
  description = "URL de acceso a WordPress"
  value       = module.load_balancer.wordpress_url
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

# ─── VPN ─────────────────────────────────────────────────────────────────────

output "vpn_gateway_public_ip" {
  description = "IP publica del gateway VPN de GCP para entregar al cliente."
  value       = var.vpn_enabled ? google_compute_address.vpn_gateway[0].address : null
}

output "vpn_peer_ip" {
  description = "IP publica del gateway VPN on-premise del cliente."
  value       = var.vpn_enabled ? var.vpn_peer_ip : null
}

output "vpn_remote_cidrs" {
  description = "Rangos on-premise enrutados por la VPN estatica."
  value       = var.vpn_enabled ? local.vpn_remote_cidrs_effective : []
}

output "vpn_shared_secret" {
  description = "Pre-shared key de la VPN. Extraer solo con terraform output -raw vpn_shared_secret y compartir por canal seguro."
  value       = var.vpn_enabled ? local.vpn_shared_secret_effective : null
  sensitive   = true
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

output "cloud_dns_records_managed_by_terraform" {
  description = "Resumen de registros DNS que Terraform administra en Cloud DNS. Si está vacío, el DNS debe gestionarse fuera de Terraform."
  value = {
    external_a = var.public_dns_managed_zone != "" ? {
      zone  = var.public_dns_managed_zone
      name  = local.external_dns_name
      type  = "A"
      value = module.load_balancer.global_ip_address
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
