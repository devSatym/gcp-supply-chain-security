# -----------------------------------------------------------------------------
# GKE Module
# Production-ready private, VPC-native GKE cluster with Workload Identity,
# separately managed node pools, and per-node-pool service accounts
# (the GCP analogue of IRSA).
# -----------------------------------------------------------------------------

locals {
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
# GKE cluster (node-pool-less control plane — all compute lives in
# google_container_node_pool resources below, mirroring "managed node groups")
# -----------------------------------------------------------------------------
resource "google_container_cluster" "main" {
  provider = google-beta

  name     = var.cluster_name
  project  = var.project_id
  location = var.regional ? var.region : var.zone

  node_locations = length(var.node_locations) > 0 ? var.node_locations : null

  network    = var.network_self_link
  subnetwork = var.subnetwork_self_link

  # Managed elsewhere: node pools are defined explicitly for controlled sizing.
  remove_default_node_pool = true
  initial_node_count       = 1

  min_master_version  = var.cluster_version
  deletion_protection = false

  release_channel {
    channel = var.release_channel
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  dynamic "master_authorized_networks_config" {
    for_each = length(var.master_authorized_networks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = var.master_authorized_networks
        content {
          cidr_block   = cidr_blocks.value.cidr_block
          display_name = cidr_blocks.value.display_name
        }
      }
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  addons_config {
    horizontal_pod_autoscaling {
      disabled = false
    }
    http_load_balancing {
      disabled = false
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = var.enable_managed_prometheus
    }
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = var.maintenance_start_time
    }
  }

  resource_labels = local.labels

  lifecycle {
    ignore_changes = [
      node_config,
    ]
  }
}

# -----------------------------------------------------------------------------
# Per-node-pool service accounts (least privilege — equivalent to a node
# instance profile in EKS)
# -----------------------------------------------------------------------------
resource "google_service_account" "node_pool" {
  for_each = var.node_pools

  project      = var.project_id
  account_id   = "${substr(var.cluster_name, 0, 20)}-${each.key}"
  display_name = "GKE node pool SA for ${var.cluster_name}/${each.key}"
}

resource "google_project_iam_member" "node_pool_roles" {
  for_each = {
    for pair in flatten([
      for pool_key, pool in var.node_pools : [
        for role in var.node_pool_roles : {
          key  = "${pool_key}-${role}"
          pool = pool_key
          role = role
        }
      ]
    ]) : pair.key => pair
  }

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.node_pool[each.value.pool].email}"
}

# -----------------------------------------------------------------------------
# Managed node pools with autoscaling
# -----------------------------------------------------------------------------
resource "google_container_node_pool" "main" {
  for_each = var.node_pools

  provider = google-beta

  name     = each.key
  project  = var.project_id
  location = var.regional ? var.region : var.zone
  cluster  = google_container_cluster.main.name

  initial_node_count = each.value.desired_size

  autoscaling {
    min_node_count = each.value.min_size
    max_node_count = each.value.max_size
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = each.value.machine_type
    disk_size_gb    = lookup(each.value, "disk_size_gb", 100)
    disk_type       = lookup(each.value, "disk_type", "pd-balanced")
    spot            = lookup(each.value, "spot", false)
    service_account = google_service_account.node_pool[each.key].email

    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = local.labels

    tags = ["${var.cluster_name}-node", each.key]

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  lifecycle {
    ignore_changes = [initial_node_count]
  }
}
