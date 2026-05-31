###############################################################################
# Modulo Compute - VM unica, Unmanaged Instance Group y Health Check via LB
# Proyecto: EDUFIS - WordPress en GCP
#
# Componentes:
#   - VM unica con WordPress y MySQL local
#   - Unmanaged Instance Group zonal para conectar la VM al Load Balancer
###############################################################################

# --- Data source: Imagen mas reciente del SO ---------------------------------

data "google_compute_image" "base" {
  family  = var.image_family
  project = var.image_project
}

resource "terraform_data" "subnet_change" {
  triggers_replace = [
    var.subnet_change_token,
    var.private_ip,
  ]
}

# --- VM unica ----------------------------------------------------------------

resource "google_compute_instance" "wordpress" {
  name         = "${var.name_prefix}-wordpress-vm"
  project      = var.project_id
  zone         = var.zone
  machine_type = var.machine_type
  description  = "VM unica para WordPress y MySQL - ${var.name_prefix}"

  # Permite que Terraform detenga y arranque la VM para cambios que GCP no
  # acepta en caliente, como mover la NIC a otra subred.
  allow_stopping_for_update = true

  tags = [var.wordpress_tag]

  labels = merge(var.labels, {
    role = "wordpress"
  })

  boot_disk {
    auto_delete = true

    initialize_params {
      image = data.google_compute_image.base.self_link
      type  = var.boot_disk_type
      size  = var.boot_disk_size_gb

      labels = var.labels
    }
  }

  # Sin IP publica: salida a internet via Cloud NAT.
  network_interface {
    subnetwork = var.subnet_self_link
    network_ip = var.private_ip
  }

  service_account {
    email = var.service_account_email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  metadata = {
    startup-script             = var.startup_script
    enable-oslogin             = "FALSE"
    block-project-ssh-keys     = "FALSE"
    serial-port-logging-enable = "FALSE"
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
    provisioning_model  = "STANDARD"
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  lifecycle {
    create_before_destroy = false

    ignore_changes = [
      boot_disk[0].initialize_params[0].image,
      metadata["ssh-keys"],
    ]

    replace_triggered_by = [
      terraform_data.subnet_change,
    ]
  }
}

# --- Unmanaged Instance Group ------------------------------------------------
# El Load Balancer requiere un backend de tipo instance group. Para una sola VM,
# un unmanaged instance group mantiene la arquitectura simple sin autoscaling.

resource "google_compute_instance_group" "wordpress" {
  name        = "${var.name_prefix}-wordpress-ig"
  project     = var.project_id
  zone        = var.zone
  description = "Unmanaged instance group para la VM WordPress - ${var.name_prefix}"

  instances = [
    google_compute_instance.wordpress.self_link,
  ]

  named_port {
    name = "http"
    port = 80
  }
}
