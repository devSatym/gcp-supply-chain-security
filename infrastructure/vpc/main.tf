# -----------------------------------------------------------------------------
# VPC Module — GCP
# Custom-mode VPC, public/private subnets with secondary ranges for GKE,
# Cloud Router + Cloud NAT, firewall rules and VPC Flow Logs.
# -----------------------------------------------------------------------------

locals {
  name_prefix = "${var.name}-${var.environment}"

  labels = merge(
    var.labels,
    {
      environment = var.environment
      owner       = var.owner
      project     = var.project_label
      cost_center = var.cost_center
      managed_by  = "terraform"
    }
  )
}

# -----------------------------------------------------------------------------
# VPC Network
# -----------------------------------------------------------------------------
resource "google_compute_network" "main" {
  name                            = "${local.name_prefix}-vpc"
  project                         = var.project_id
  auto_create_subnetworks         = false
  routing_mode                    = var.routing_mode
  mtu                             = var.mtu
  delete_default_routes_on_create = false
}

# -----------------------------------------------------------------------------
# Private subnets (GKE nodes) — one per region/zone entry, with secondary
# ranges for pods and services so the GKE module can use VPC-native clusters.
# -----------------------------------------------------------------------------
resource "google_compute_subnetwork" "private" {
  for_each = var.private_subnets

  name    = "${local.name_prefix}-private-${each.key}"
  project = var.project_id
  region  = var.region
  network = google_compute_network.main.id

  ip_cidr_range = each.value.cidr_block

  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "${each.key}-pods"
    ip_cidr_range = each.value.pods_cidr_block
  }

  secondary_ip_range {
    range_name    = "${each.key}-services"
    ip_cidr_range = each.value.services_cidr_block
  }

  dynamic "log_config" {
    for_each = var.enable_flow_logs ? [1] : []
    content {
      aggregation_interval = var.flow_logs_interval
      flow_sampling        = var.flow_logs_sampling
      metadata             = "INCLUDE_ALL_METADATA"
    }
  }
}

# -----------------------------------------------------------------------------
# Public subnets (load balancers, bastion, NAT-facing resources)
# -----------------------------------------------------------------------------
resource "google_compute_subnetwork" "public" {
  for_each = var.public_subnets

  name    = "${local.name_prefix}-public-${each.key}"
  project = var.project_id
  region  = var.region
  network = google_compute_network.main.id

  ip_cidr_range = each.value.cidr_block

  dynamic "log_config" {
    for_each = var.enable_flow_logs ? [1] : []
    content {
      aggregation_interval = var.flow_logs_interval
      flow_sampling        = var.flow_logs_sampling
      metadata             = "INCLUDE_ALL_METADATA"
    }
  }
}

# -----------------------------------------------------------------------------
# Cloud Router + Cloud NAT (equivalent to AWS NAT Gateways)
# -----------------------------------------------------------------------------
resource "google_compute_router" "main" {
  name    = "${local.name_prefix}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.main.id
}

resource "google_compute_router_nat" "main" {
  name    = "${local.name_prefix}-nat"
  project = var.project_id
  region  = var.region
  router  = google_compute_router.main.name

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  dynamic "subnetwork" {
    for_each = google_compute_subnetwork.private
    content {
      name                    = subnetwork.value.id
      source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
    }
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# -----------------------------------------------------------------------------
# Firewall rules — least privilege baseline
# -----------------------------------------------------------------------------
resource "google_compute_firewall" "allow_internal" {
  name    = "${local.name_prefix}-allow-internal"
  project = var.project_id
  network = google_compute_network.main.id

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = concat(
    [for s in var.private_subnets : s.cidr_block],
    [for s in var.public_subnets : s.cidr_block]
  )
}

resource "google_compute_firewall" "allow_iap_ssh" {
  count = var.enable_iap_ssh ? 1 : 0

  name    = "${local.name_prefix}-allow-iap-ssh"
  project = var.project_id
  network = google_compute_network.main.id

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # IAP TCP forwarding range — never open SSH to the whole internet.
  source_ranges = ["35.235.240.0/20"]
}

resource "google_compute_firewall" "deny_all_ingress" {
  name    = "${local.name_prefix}-deny-all-ingress"
  project = var.project_id
  network = google_compute_network.main.id

  direction = "INGRESS"
  priority  = 65534

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
}
