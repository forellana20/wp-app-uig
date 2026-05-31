# 🌐 Terraform - WordPress en Google Cloud Platform

## Proyecto EDUFIS - Migración Lift & Shift

Infraestructura como Código (IaC) para desplegar WordPress en GCP con una VM única, balanceo de carga y seguridad gestionada.

---

## 📐 Arquitectura

```
                                    ┌─────────────────────────────────────────────────┐
                                    │              Google Cloud Platform               │
                                    │                    us-east1                     │
                                    │                                                  │
                                    │  ┌──────────┐    ┌──────────────────────────┐   │
                                    │  │  Cloud    │    │ Unmanaged Instance Group │   │
 ┌──────┐   HTTPS    ┌──────────┐  │  │  Armor   │    │                          │   │
 │      │ ────────►  │    LB    │──┼─►│  (WAF)   │───►│       ┌────────┐         │   │
 │ User │            │  HTTP(S) │  │  │  SQLi    │    │       │  VM    │         │   │
 │      │            │  + SSL   │  │  │  XSS     │    │       │  WP+   │         │   │
 └──────┘            │  + CDN   │  │  │  LFI/RFI │    │       │ MySQL  │         │   │
                     └──────────┘  │  └──────────┘    │       │ Apache │         │   │
                     IP Estática   │                   │       └────────┘         │   │
                     Global        │                   │        us-east1-b        │   │
                                    │                   └──────────────────────────┘   │
                                    │                                                  │
                                    │  ┌──────────────┐  ┌──────────────────────┐     │
                                    │  │ Cloud Router  │  │   Cloud NAT          │     │
                                    │  │ + VPN (opt.)  │  │   (Salida Internet)  │     │
                                    │  └──────────────┘  └──────────────────────┘     │
 ┌──────────┐  VPN   │             │                                                  │
 │ Oficinas │ ◄──────┼─────────────┤   Firewall Rules:                               │
 │ (admin)  │        │             │    HTTP/HTTPS desde LB                         │
 └──────────┘        │             │    SSH desde IAP/VPN                            │
                                    │   Todo lo demás denegado                      │
                                    └─────────────────────────────────────────────────┘
```

---

## 📁 Estructura del Proyecto

```
terraform-wordpress-gcp/
├── main.tf                     # Orquestación de módulos
├── variables.tf                # Variables globales
├── outputs.tf                  # Outputs del despliegue
├── locals.tf                   # Valores derivados y constantes
├── providers.tf                # Configuración de providers
├── versions.tf                 # Versiones de Terraform y providers
├── backend.tf                  # Backend remoto (GCS)
├── vpn.tf                      # Configuración VPN (comentada)
├── terraform.tfvars            # Variables locales (no versionar secretos)
├── .gitignore
├── scripts/
│   └── startup.sh              # Script de instalación WordPress
└── modules/
    ├── network/                # VPC, Subred, Cloud Router, Cloud NAT
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── security/               # Firewall, Cloud Armor, Service Account
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── compute/                # VM única y Unmanaged Instance Group
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── load-balancer/          # LB HTTP(S), SSL, IP Global, CDN
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

---

## ✅ Prerequisitos

1. **Google Cloud SDK** instalado y configurado
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```

2. **Terraform** >= 1.5.0
   ```bash
   terraform version
   ```

3. **Proyecto en GCP** con las siguientes APIs habilitadas:
   ```bash
   gcloud services enable \
     compute.googleapis.com \
     cloudresourcemanager.googleapis.com \
     iam.googleapis.com \
     logging.googleapis.com \
     monitoring.googleapis.com \
     secretmanager.googleapis.com \
     --project=<PROJECT_ID>
   ```

4. **Permisos IAM** necesarios para la cuenta que ejecuta Terraform:
   - `roles/compute.admin`
   - `roles/iam.serviceAccountAdmin`
   - `roles/iam.serviceAccountUser`
   - `roles/resourcemanager.projectIamAdmin`

---

## 🚀 Guía de Despliegue

### Paso 1: Configurar Variables

```bash
cd terraform-wordpress-gcp/
```

Crear o editar `terraform.tfvars` con los valores reales:

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `project_id` | ID del proyecto GCP | `mi-proyecto-123` |
| `region` | Región de despliegue | `us-east1` |
| `prefix` | Prefijo de recursos | `edufis` |
| `environment` | Ambiente (`dev` o `prod`) | `dev` |
| `subnet_cidr` | Subred de aplicación DEV; si se omite usa el rango aprobado de DEV | `10.133.0.0/25` |
| `proxy_subnet_cidr` | Proxy-only subnet DEV para futuro LB interno/regional | `10.133.0.128/25` |
| `wp_db_name` | Nombre de la base de datos de WordPress; debe coincidir con el dump migrado | `edufis_db` |
| `wp_db_user` | Usuario MySQL usado por WordPress | `wp_edufis` |
| `wp_db_password_secret_id` | ID del secreto de Secret Manager con la contraseña MySQL | `edufis-dev-wp-db-password` |
| `wp_table_prefix` | Prefijo de tablas del dump SQL | `gob_` |
| `wp_source_url` | URL original a reemplazar en el dump | `http://localhost/edufis` |
| `wp_target_url` | URL destino; vacío usa `https://domain` | `https://www.edufis-test-ext.mh.gob.sv` |
| `wordpress_source_bucket` | Bucket existente para leer WordPress/dumps | `portal-edufis` |
| `wordpress_source_gcs_uri` | ZIP/TAR o prefijo GCS con archivos de WordPress | `gs://portal-edufis/wordpress/` |
| `wordpress_db_dump_gcs_uri` | Dump SQL opcional a importar | `gs://portal-edufis/database/edufis_db.sql` |
| `domain` | Dominio para SSL | `edufis.example.com` |
| `public_dns_managed_zone` | Zona Cloud DNS pública para crear el A externo automáticamente. Vacío si DNS lo administra el cliente | `""` |
| `internal_dns_managed_zone` | Zona Cloud DNS privada para crear el A interno automáticamente. Vacío si DNS lo administra el cliente | `""` |
| `certificate_dns_authorization_managed_zone` | Zona Cloud DNS autoritativa para crear el CNAME de autorización del certificado interno. Vacío usa `public_dns_managed_zone` si existe | `""` |

### Paso 2: Inicializar Terraform

```bash
terraform init
```

### Paso 3: Revisar el Plan

```bash
terraform plan -out=tfplan
```

### Paso 4: Aplicar

```bash
terraform apply tfplan
```

### Paso 5: Configurar DNS

Después del despliegue, Terraform mostrará los registros DNS requeridos. Si el DNS lo administra el cliente fuera de GCP, solicitar la creación manual de estos registros. Si existen zonas Cloud DNS administradas en el proyecto, configurar `public_dns_managed_zone`, `internal_dns_managed_zone` y/o `certificate_dns_authorization_managed_zone` para que Terraform cree los registros automáticamente.

```bash
# Ver la IP del Load Balancer externo
terraform output load_balancer_ip

# Ver instrucciones completas de DNS externo e interno
terraform output dns_instructions
terraform output internal_dns_instructions

# Ver registros administrados por Terraform en Cloud DNS, si aplica
terraform output cloud_dns_records_managed_by_terraform
```

Registros esperados para el ambiente DEV actual:

| Uso | Nombre | Tipo | Valor |
|-----|--------|------|-------|
| Externo público | `www.edufis-dev-ext.mh.gob.sv` | `A` | IP pública del output `load_balancer_ip` |
| Interno privado | `www.edufis-dev-int.mh.gob.sv` | `A` | IP privada del output `internal_load_balancer_ip` |
| Validación certificado interno | `_acme-challenge_xpkldmcy2xhsao7y.www.edufis-dev-int.mh.gob.sv.` | `CNAME` | Valor del output `internal_dns_instructions` |

El registro `A` externo debe resolver públicamente para que el certificado externo Google-managed salga de `FAILED_NOT_VISIBLE`. El registro `CNAME` de validación del certificado interno debe estar en el DNS autoritativo consultable por Google; el `A` interno puede permanecer solo en DNS privado corporativo.

### Paso 6: Verificar

```bash
# Verificar que la VM esté en el unmanaged instance group
gcloud compute instance-groups unmanaged list-instances \
  edufis-dev-wordpress-ig \
  --project=<PROJECT_ID> \
  --zone=us-east1-b

# Verificar el certificado SSL (puede tomar 15-60 minutos)
gcloud compute ssl-certificates describe edufis-prod-wordpress-ssl \
  --project=<PROJECT_ID> --global
```

---

## 🔐 Seguridad Implementada

| Componente | Descripción |
|------------|-------------|
| **Cloud Armor** | WAF con reglas contra SQLi, XSS, LFI, RFI + Rate Limiting |
| **Firewall** | Solo permite tráfico desde LB y SSH desde IAP/VPN |
| **IAP SSH** | Acceso SSH sin IP pública, autenticado con Google Identity |
| **Service Account** | Permisos mínimos (logging + monitoring) |
| **Shielded VM** | Secure Boot, vTPM, Integrity Monitoring |
| **OS Login** | Autenticación SSH via IAM de Google |
| **SSL/TLS** | Certificado gestionado por Google, redirect HTTP→HTTPS |
| **Apache hardening** | Bloqueo de xmlrpc, archivos sensibles y headers de seguridad |
| **Sin IP pública** | VMs solo accesibles via LB o IAP |

---

## 🔧 Configuración VPN

Para habilitar la VPN con la red on-premise:

1. Editar `vpn.tf` y descomentar los recursos
2. Agregar las variables de VPN a `terraform.tfvars`:
   ```hcl
   vpn_peer_ip      = "203.0.113.1"      # IP del gateway on-premise
   vpn_shared_secret = "mi-secreto-vpn"   # Pre-shared key
   vpn_peer_asn     = 65515               # ASN del peer BGP
   ```
3. Ejecutar `terraform plan` y `terraform apply`

---

## 📊 Monitoreo y Logging

La infraestructura incluye:

- **Google Cloud Ops Agent** en la VM para:
  - Logs de Apache (access + error)
  - Logs de MySQL (error + slow queries)
  - Métricas de Apache y MySQL
- **Health Check** del Load Balancer para verificar `/health`
- **Flow Logs** en la subred
- **Firewall Logs** habilitados

---

## 🛠 Troubleshooting

### Las instancias no pasan el health check

```bash
# Verificar el startup script
gcloud compute instances get-serial-port-output <INSTANCE_NAME> \
  --project=<PROJECT_ID> --zone=<ZONE>

# Conectarse via IAP para diagnosticar
gcloud compute ssh <INSTANCE_NAME> \
  --project=<PROJECT_ID> --zone=<ZONE> \
  --tunnel-through-iap

# Dentro de la VM:
sudo systemctl status apache2
sudo systemctl status mysql
curl -I http://localhost/health
cat /var/log/startup-script.log
```

### El certificado SSL no se provisiona

1. Verificar que el DNS externo apunte públicamente a la IP del LB: `dig www.edufis-dev-ext.mh.gob.sv A`
2. Verificar que el CNAME de autorización interno resuelva desde DNS autoritativo: `dig _acme-challenge_xpkldmcy2xhsao7y.www.edufis-dev-int.mh.gob.sv CNAME`
3. Esperar 15-60 minutos después de configurar DNS
4. Verificar estado del certificado externo: `gcloud compute ssl-certificates describe edufis-dev-wordpress-ssl --global --project=<PROJECT_ID>`
5. Verificar estado del certificado interno: `gcloud certificate-manager certificates describe edufis-dev-wordpress-int-cert --location=us-east1 --project=<PROJECT_ID>`

### Error de permisos al aplicar Terraform

```bash
# Verificar la cuenta activa
gcloud auth list

# Verificar permisos del proyecto
gcloud projects get-iam-policy <PROJECT_ID> \
  --flatten="bindings[].members" \
  --filter="bindings.members:$(gcloud config get-value account)"
```

### Las instancias no tienen acceso a internet

Verificar que Cloud NAT esté funcionando:
```bash
gcloud compute routers nats describe edufis-prod-nat \
  --router=edufis-prod-router \
  --region=us-east1 \
  --project=<PROJECT_ID>
```

---

## 📝 Mejores Prácticas Implementadas

- ✅ **Modularización**: Código organizado en módulos reutilizables
- ✅ **Backend remoto**: Ejemplo de configuración con GCS (backend.tf)
- ✅ **Variables con validación**: Restricciones en valores aceptados
- ✅ **Nomenclatura consistente**: `{prefix}-{environment}-{recurso}`
- ✅ **Etiquetas**: Labels en todos los recursos para gestión de costos
- ✅ **Versiones fijas**: Providers con version constraints
- ✅ **Data sources**: Imagen base obtenida dinámicamente
- ✅ **Dependencias explícitas**: `depends_on` donde es necesario
- ✅ **Valores sensibles**: `sensitive = true` para contraseñas
- ✅ **VM única**: Arquitectura simple para bajo tráfico y MySQL local
- ✅ **Unmanaged instance group**: Backend compatible con Load Balancer sin autoscaling

---

## ⚠️ Consideraciones Importantes

### WordPress + MySQL en la misma VM (Lift & Shift)

Esta arquitectura coloca WordPress y MySQL en la misma VM como parte de una migración lift & shift. Para una arquitectura más robusta en el futuro, considerar:

1. **Cloud SQL** para MySQL gestionado (backups, HA, réplicas)
2. **Filestore/GCS FUSE** para `wp-content` compartido entre instancias
3. **Memorystore (Redis)** para caché de sesiones y objetos
4. **Cloud CDN** ya incluido en esta configuración

### Escalamiento futuro

La arquitectura usa una sola VM para mantener WordPress y MySQL locales. Si el tráfico crece o se requiere alta disponibilidad, considerar:

1. **Cloud SQL** para separar MySQL de la VM
2. **Filestore/GCS FUSE** para `wp-content` compartido
3. **Managed Instance Group** si se necesitan múltiples instancias
4. **Memorystore (Redis)** para caché de sesiones y objetos

### Costos Estimados (us-east1, precios On-Demand)

| Recurso | Especificación | Costo Aprox./mes |
|---------|---------------|-------------------|
| 1x e2-medium | 2 vCPU, 4GB RAM | ~$25 |
| 1x pd-balanced 50GB | Disco persistente | ~$5 |
| Load Balancer | Forwarding rules + data | ~$20-50 |
| Cloud NAT | Gateway + data | ~$5-15 |
| Cloud Armor | Política + requests | ~$5-20 |
| **Total estimado** | | **~$60-115/mes** |

---

## 🗑 Destruir la Infraestructura

```bash
terraform destroy
```

> ⚠️ **PRECAUCIÓN**: Esto eliminará TODOS los recursos incluyendo datos de WordPress y MySQL. Asegurarse de tener backups antes de destruir.

---

## 📄 Licencia

Uso interno - Proyecto EDUFIS
