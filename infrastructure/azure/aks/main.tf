locals {
  tags = merge(
    var.tags,
    {
      environment = var.environment
      owner       = var.owner
      project     = var.project_label
      cost_center = var.cost_center
      managed_by  = "terraform"
    }
  )

  log_analytics_workspace_name = coalesce(var.log_analytics_workspace_name, "law-${var.cluster_name}")
}

# A user-assigned control-plane identity lets Terraform grant the required VNet
# permission before AKS provisioning begins. AKS creates and manages its own
# kubelet identity; that identity is output for ACR pull permissions.
resource "azurerm_user_assigned_identity" "control_plane" {
  name                = "${var.cluster_name}-control-plane"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = local.tags
}

resource "azurerm_role_assignment" "control_plane_network_contributor" {
  scope                = var.network_scope_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
}

resource "azurerm_log_analytics_workspace" "aks" {
  name                = local.log_analytics_workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_in_days
  tags                = local.tags
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = coalesce(var.dns_prefix, var.cluster_name)

  kubernetes_version        = var.kubernetes_version
  automatic_upgrade_channel = var.automatic_upgrade_channel
  node_os_upgrade_channel   = var.node_os_upgrade_channel
  sku_tier                  = var.sku_tier

  role_based_access_control_enabled = true
  local_account_disabled            = true
  private_cluster_enabled           = true
  private_dns_zone_id               = var.private_dns_zone_id
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true

  # Azure RBAC is the Kubernetes authorization plane. Cluster access is
  # granted with Azure RBAC roles rather than static administrator credentials.
  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = true
    tenant_id              = var.tenant_id
    admin_group_object_ids = var.azure_rbac_admin_group_object_ids
  }

  # This dedicated, delegated subnet keeps the private API server within the
  # workload VNet while nodes remain in their separate VMSS subnet.
  api_server_access_profile {
    subnet_id                           = var.api_server_subnet_id
    virtual_network_integration_enabled = true
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.control_plane.id]
  }

  default_node_pool {
    name                        = var.system_node_pool.name
    vm_size                     = var.system_node_pool.vm_size
    vnet_subnet_id              = var.node_subnet_id
    auto_scaling_enabled        = true
    min_count                   = var.system_node_pool.min_size
    max_count                   = var.system_node_pool.max_size
    node_count                  = var.system_node_pool.desired_size
    os_disk_size_gb             = var.system_node_pool.os_disk_size_gb
    os_disk_type                = var.system_node_pool.os_disk_type
    max_pods                    = var.system_node_pool.max_pods
    zones                       = var.system_node_pool.zones
    node_labels                 = merge(local.tags, var.system_node_pool.node_labels)
    tags                        = local.tags
    type                        = "VirtualMachineScaleSets"
    temporary_name_for_rotation = var.system_node_pool.temporary_name_for_rotation

    upgrade_settings {
      max_surge = var.node_pool_max_surge
    }
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "azure"
    load_balancer_sku   = "standard"
    outbound_type       = "userAssignedNATGateway"
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
  }

  oms_agent {
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.aks.id
    msi_auth_for_monitoring_enabled = true
  }

  dynamic "monitor_metrics" {
    for_each = var.enable_azure_monitor_metrics ? [1] : []

    content {
      annotations_allowed = var.azure_monitor_metrics_annotations_allowed
      labels_allowed      = var.azure_monitor_metrics_labels_allowed
    }
  }

  dynamic "maintenance_window_auto_upgrade" {
    for_each = var.enable_maintenance_windows ? [1] : []

    content {
      frequency  = var.maintenance_window_frequency
      interval   = var.maintenance_window_interval
      duration   = var.maintenance_window_duration_hours
      start_time = var.maintenance_window_start_time
      utc_offset = var.maintenance_window_utc_offset
    }
  }

  dynamic "maintenance_window_node_os" {
    for_each = var.enable_maintenance_windows ? [1] : []

    content {
      frequency  = var.maintenance_window_frequency
      interval   = var.maintenance_window_interval
      duration   = var.maintenance_window_duration_hours
      start_time = var.maintenance_window_start_time
      utc_offset = var.maintenance_window_utc_offset
    }
  }

  tags = local.tags

  depends_on = [azurerm_role_assignment.control_plane_network_contributor]

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count,
    ]

    precondition {
      condition     = !var.system_node_pool.spot
      error_message = "The AKS system node pool must use regular-capacity nodes; use user_node_pools for Spot capacity."
    }
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  for_each = var.user_node_pools

  name                  = each.value.name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = each.value.vm_size
  mode                  = "User"
  vnet_subnet_id        = var.node_subnet_id
  auto_scaling_enabled  = true
  min_count             = each.value.min_size
  max_count             = each.value.max_size
  node_count            = each.value.desired_size
  os_disk_size_gb       = each.value.os_disk_size_gb
  os_disk_type          = each.value.os_disk_type
  max_pods              = each.value.max_pods
  zones                 = each.value.zones
  node_labels           = merge(local.tags, each.value.node_labels)
  node_taints           = each.value.node_taints
  priority              = each.value.spot ? "Spot" : "Regular"
  eviction_policy       = each.value.spot ? "Delete" : null
  spot_max_price        = each.value.spot ? -1 : null
  tags                  = local.tags

  upgrade_settings {
    max_surge = var.node_pool_max_surge
  }

  lifecycle {
    ignore_changes = [node_count]
  }
}

# ACR is introduced by the following registry milestone, so the association is
# optional. Passing an ACR resource ID grants only the AKS kubelet identity
# pull rights; it never grants registry access to the control-plane identity.
resource "azurerm_role_assignment" "kubelet_acr_pull" {
  count = var.acr_id == null ? 0 : 1

  scope                            = var.acr_id
  role_definition_name             = var.acr_pull_role_definition_name
  principal_id                     = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}
