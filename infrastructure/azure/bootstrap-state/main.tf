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
}

# This configuration is deliberately separate from the workload environment.
# Terraform cannot use a Blob backend that it is creating in the same run.
resource "azurerm_resource_group" "state" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_storage_account" "state" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.state.name
  location                 = azurerm_resource_group.state.location
  account_tier             = "Standard"
  account_kind             = "StorageV2"
  account_replication_type = var.account_replication_type

  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  public_network_access_enabled   = var.public_network_access_enabled

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = var.blob_soft_delete_retention_days
    }

    container_delete_retention_policy {
      days = var.container_soft_delete_retention_days
    }
  }

  # When public connectivity is enabled, the account remains firewall-denied
  # except for declared runner egress ranges and subnets.
  network_rules {
    default_action = "Deny"
    bypass         = []
    # Azure storage firewall ip_rules reject /32 (and /31) prefixes; a bare
    # IPv4 address means exactly that host. Keep single-host entries usable.
    ip_rules                   = [for cidr in var.allowed_ip_ranges : trimsuffix(cidr, "/32")]
    virtual_network_subnet_ids = var.allowed_subnet_ids
  }

  tags = local.tags

  lifecycle {
    precondition {
      condition     = !var.public_network_access_enabled || length(var.allowed_ip_ranges) > 0 || length(var.allowed_subnet_ids) > 0
      error_message = "When public_network_access_enabled is true, declare at least one trusted runner egress IP range or subnet. The state account must not be broadly reachable."
    }
  }
}

resource "azurerm_storage_account_queue_properties" "state" {
  storage_account_id = azurerm_storage_account.state.id

  logging {
    version               = "1.0"
    delete                = true
    read                  = true
    write                 = true
    retention_policy_days = 30
  }
}

# The account-level role assignment is intentionally created before the
# container. With shared-key access disabled, Terraform itself uses Entra ID
# data-plane authorization to create and access the container.
resource "azurerm_role_assignment" "state_operator" {
  for_each = var.state_operator_principal_ids

  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = each.value
}

resource "azurerm_storage_container" "state" {
  name                  = var.container_name
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"

  depends_on = [azurerm_role_assignment.state_operator]
}

# This root owns the optional endpoint so bootstrap remains a local-backend
# operation and does not depend on the workload root's remote state.
resource "azurerm_private_endpoint" "state_blob" {
  count = var.enable_private_endpoint ? 1 : 0

  name                = "${var.storage_account_name}-blob-pe"
  location            = azurerm_resource_group.state.location
  resource_group_name = azurerm_resource_group.state.name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = local.tags

  private_service_connection {
    name                           = "${var.storage_account_name}-blob"
    private_connection_resource_id = azurerm_storage_account.state.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "blob-dns"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }
}
