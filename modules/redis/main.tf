terraform {
  required_version = ">= 0.12"
}

data "google_compute_network" "default-network" {
  provider = google
  name     = "default-network"
  project  = var.gcp_project
}

// https://github.com/terraform-google-modules/terraform-google-memorystore
module "memorystore" {
  source  = "terraform-google-modules/memorystore/google"
  version = "1.0.0"

  name     = length(var.redis_instance_custom_name) > 0 ? var.redis_instance_custom_name : "${var.labels.app}-${var.kubernetes_namespace}-${random_id.suffix.hex}"
  project = var.gcp_project

  location_id        = var.zone
  authorized_network = "${data.google_compute_network.default-network.self_link}"

  enable_apis = "${var.enable_apis}"

  reserved_ip_range = var.reserved_ip_range

  labels = var.labels
}

resource "random_id" "protector" {
  count       = var.prevent_destroy ? 1 : 0
  byte_length = 8
  keepers = {
    protector = module.memorystore.id
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "random_id" "suffix" {
  byte_length = 2
}

resource "kubernetes_config_map" "team-redis-configmap" {
  depends_on = [
    module.memorystore
  ]

  metadata {
    name      = "${var.labels.app}-redis-configmap"
    namespace = var.kubernetes_namespace
    labels    = var.labels
  }

  data = {
    REDIS_HOST = module.memorystore.host
  }
}
