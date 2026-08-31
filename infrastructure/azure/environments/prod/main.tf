# Azure production environment root.
#
# Composition order (strict dependency direction):
#   network -> aks -> supply-chain -> (kubernetes-addons, falco)
#   falco-alerting -> falco (Event Hub coordinates + sidekick identity)
#
# The apply-once runner performs the staged convergence documented in README.md:
#   foundation -> private API probe -> add-ons/Argo/Falco -> endpoint probe
#   -> optional public-service closure.

check "private_service_closure" {
  assert {
    condition     = !var.disable_public_network_access || var.enable_private_endpoints
    error_message = "disable_public_network_access requires enable_private_endpoints. Create and probe private endpoints before closing public service access."
  }
}

check "runtime_alerting_secret_lifecycle" {
  assert {
    condition = !var.enable_runtime_alerting || (
      var.discord_webhook_url != "" &&
      var.discord_webhook_secret_expiration_date != null &&
      trimspace(var.discord_webhook_secret_expiration_date) != ""
    )
    error_message = "enable_runtime_alerting requires TF_VAR_discord_webhook_url and an owner-supplied discord_webhook_secret_expiration_date."
  }
}

locals {
  tags = merge(
    var.tags,
    {
      environment = var.environment
      owner       = var.owner
      project     = var.project_label
      cost_center = var.cost_center
      managed_by  = "terraform"
      component   = "azure-supply-chain-prod"
    },
  )
}

module "network" {
  source = "../../network"

  resource_group_name = var.resource_group_name
  location            = var.location
  vnet_name           = var.vnet_name

  vnet_address_space                         = var.vnet_address_space
  aks_nodes_subnet_name                      = var.aks_nodes_subnet_name
  aks_nodes_subnet_address_prefixes          = var.aks_nodes_subnet_address_prefixes
  aks_api_server_subnet_address_prefixes     = var.aks_api_server_subnet_address_prefixes
  private_endpoints_subnet_address_prefixes  = var.private_endpoints_subnet_address_prefixes
  functions_subnet_address_prefixes          = var.functions_subnet_address_prefixes
  private_runner_subnet_name                 = var.private_runner_subnet_name
  private_runner_subnet_address_prefixes     = var.private_runner_subnet_address_prefixes
  attach_nat_gateway_to_private_runner       = var.attach_nat_gateway_to_private_runner
  owner_ssh_allow_cidr                       = var.owner_ssh_allow_cidr
  enable_flow_logs                           = var.enable_flow_logs
  flow_logs_storage_account_name             = var.flow_logs_storage_account_name
  flow_logs_storage_account_replication_type = var.flow_logs_storage_account_replication_type
  flow_logs_retention_days                   = var.flow_logs_retention_days

  environment   = var.environment
  owner         = var.owner
  project_label = var.project_label
  cost_center   = var.cost_center
  tags          = local.tags
}

module "aks" {
  source = "../../aks"

  resource_group_name  = module.network.resource_group_name
  location             = module.network.location
  cluster_name         = var.cluster_name
  network_scope_id     = module.network.vnet_id
  node_subnet_id       = module.network.aks_nodes_subnet_id
  api_server_subnet_id = module.network.aks_api_server_subnet_id

  sku_tier       = var.aks_sku_tier
  pod_cidr       = var.pod_cidr
  service_cidr   = var.service_cidr
  dns_service_ip = var.dns_service_ip

  node_os_upgrade_channel           = var.node_os_upgrade_channel
  enable_maintenance_windows        = var.enable_maintenance_windows
  maintenance_window_frequency      = var.maintenance_window_frequency
  maintenance_window_interval       = var.maintenance_window_interval
  maintenance_window_duration_hours = var.maintenance_window_duration_hours
  maintenance_window_start_time     = var.maintenance_window_start_time
  maintenance_window_utc_offset     = var.maintenance_window_utc_offset

  azure_rbac_admin_group_object_ids = var.azure_rbac_admin_group_object_ids
  system_node_pool                  = var.system_node_pool
  user_node_pools                   = var.user_node_pools

  environment   = var.environment
  owner         = var.owner
  project_label = var.project_label
  cost_center   = var.cost_center
  tags          = local.tags
}

module "supply_chain" {
  source = "../../supply-chain"

  resource_group_name = module.network.resource_group_name
  location            = module.network.location
  name_prefix         = var.name_prefix
  acr_name            = var.acr_name

  application_repository     = var.application_repository
  cosign_metadata_repository = var.cosign_metadata_repository

  aks_oidc_issuer_url      = module.aks.oidc_issuer_url
  aks_kubelet_principal_id = module.aks.kubelet_identity_object_id

  github_oidc_subject                    = var.github_oidc_subject
  enable_github_terraform_identity       = var.enable_github_terraform_identity
  terraform_workload_scope_id            = module.network.resource_group_id
  terraform_aks_scope_id                 = module.aks.cluster_id
  terraform_state_storage_account_id     = var.terraform_state_storage_account_id
  terraform_state_reader_assignment_name = var.terraform_state_reader_assignment_name

  # This is flipped only by the final closure apply, after the endpoints are
  # created and the runner has proven private DNS/connectivity.
  public_network_access_enabled = !var.disable_public_network_access

  tags = local.tags
}

module "private_runner" {
  source = "../../private-runner"
  count  = var.enable_private_runner ? 1 : 0

  resource_group_name        = module.network.resource_group_name
  location                   = module.network.location
  subnet_id                  = module.network.private_runner_subnet_id
  name_prefix                = var.name_prefix
  admin_ssh_public_key       = var.private_runner_admin_ssh_public_key
  vm_size                    = var.private_runner_vm_size
  encryption_at_host_enabled = var.private_runner_encryption_at_host_enabled
  tags                       = local.tags
}

module "monitoring" {
  source = "../../monitoring"
  count  = var.enable_monitoring ? 1 : 0

  resource_group_name = module.network.resource_group_name
  location            = module.network.location
  name_prefix         = var.name_prefix
  aks_cluster_id      = module.aks.cluster_id
  acr_id              = module.supply_chain.acr_id
  retention_in_days   = var.log_analytics_retention_in_days
  tags                = local.tags
}

module "kubernetes_addons" {
  source = "../../kubernetes-addons"

  count = var.enable_workload_addons ? 1 : 0

  kyverno_client_id      = module.supply_chain.kyverno_client_id
  acr_login_server       = module.supply_chain.acr_login_server
  application_repository = module.supply_chain.application_repository
  cosign_repository      = module.supply_chain.cosign_metadata_repository

  kyverno_chart_version = var.kyverno_chart_version
  install_policy        = var.install_kyverno_policy
  argocd_chart_version  = var.argocd_chart_version
  install_argocd        = var.install_argocd

  depends_on = [module.aks]
}

module "falco_alerting" {
  source = "../../falco-alerting"

  count = var.enable_runtime_alerting ? 1 : 0

  resource_group_name = module.network.resource_group_name
  location            = module.network.location
  name_prefix         = var.alerting_name_prefix

  aks_oidc_issuer_url                    = module.aks.oidc_issuer_url
  discord_webhook_url                    = var.discord_webhook_url
  discord_webhook_secret_version         = var.discord_webhook_secret_version
  discord_webhook_secret_expiration_date = var.discord_webhook_secret_expiration_date
  trusted_public_ip_ranges               = var.alerting_trusted_public_ip_ranges
  virtual_network_subnet_id              = module.network.functions_subnet_id

  # This is flipped only by the final closure apply, after the endpoints are
  # created and the Function's private storage path has been probed.
  public_network_access_enabled = !var.disable_public_network_access

  tags = local.tags
}

module "falco" {
  source = "../../falco"

  count = var.enable_workload_addons ? 1 : 0

  # Falcosidekick is the optional alerting relay. Keep Falco runtime
  # detection enabled without scheduling relay replicas when alerting is off.
  enable_falcosidekick    = var.enable_runtime_alerting
  falcosidekick_client_id = try(module.falco_alerting[0].falcosidekick_client_id, null)
  eventhub_namespace_fqdn = try(module.falco_alerting[0].eventhub_namespace_fqdn, null)
  eventhub_name           = try(module.falco_alerting[0].eventhub_name, null)
  minimum_priority        = var.falco_minimum_priority
  custom_rules_yaml       = file("${path.module}/../../falco/custom-rules.yaml")

  depends_on = [module.kubernetes_addons]
}

# Least-privilege AKS deployment access for the trusted-main GitHub CI
# identity reserved for an owner-approved private deployment fallback.
# Cluster User Role permits `az aks get-credentials` to obtain the
# non-admin user kubeconfig; RBAC Writer is scoped to only the `default`
# namespace the Helm release targets. No cluster-admin, Contributor, or
# resource-group-wide deployment authority is granted.
resource "azurerm_role_assignment" "github_ci_aks_cluster_user" {
  scope                            = module.aks.cluster_id
  role_definition_name             = "Azure Kubernetes Service Cluster User Role"
  principal_id                     = module.supply_chain.github_ci_principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "github_ci_aks_default_namespace_writer" {
  scope                            = "${module.aks.cluster_id}/namespaces/default"
  role_definition_name             = "Azure Kubernetes Service RBAC Writer"
  principal_id                     = module.supply_chain.github_ci_principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

# Private endpoint creation is intentionally independent from public-service
# closure. The runner first applies enable_private_endpoints=true with
# disable_public_network_access=false, probes every private path, and only
# then applies disable_public_network_access=true. Registry data endpoints are
# included because the ACR is created with data_endpoint_enabled = true.
resource "azurerm_private_endpoint" "acr_registry" {
  count = var.enable_private_endpoints ? 1 : 0

  name                = "${var.name_prefix}-acr-registry-pe"
  location            = module.network.location
  resource_group_name = module.network.resource_group_name
  subnet_id           = module.network.private_endpoints_subnet_id
  tags                = local.tags

  private_service_connection {
    name                           = "acr-registry"
    private_connection_resource_id = module.supply_chain.acr_id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "acr-registry-dns"
    private_dns_zone_ids = [module.network.private_dns_zone_ids["privatelink.azurecr.io"]]
  }
}

resource "azurerm_private_endpoint" "acr_registry_data" {
  count = var.enable_private_endpoints ? 1 : 0

  name                = "${var.name_prefix}-acr-data-pe"
  location            = module.network.location
  resource_group_name = module.network.resource_group_name
  subnet_id           = module.network.private_endpoints_subnet_id
  tags                = local.tags

  private_service_connection {
    name                           = "acr-registry-data"
    private_connection_resource_id = module.supply_chain.acr_id
    subresource_names              = ["registry_data"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "acr-data-dns"
    private_dns_zone_ids = [module.network.private_dns_zone_ids["privatelink-data.azurecr.io"]]
  }
}

resource "azurerm_private_endpoint" "key_vault" {
  count = var.enable_private_endpoints && var.enable_runtime_alerting ? 1 : 0

  name                = "${var.name_prefix}-falco-kv-pe"
  location            = module.network.location
  resource_group_name = module.network.resource_group_name
  subnet_id           = module.network.private_endpoints_subnet_id
  tags                = local.tags

  private_service_connection {
    name                           = "falco-key-vault"
    private_connection_resource_id = module.falco_alerting[0].key_vault_id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "key-vault-dns"
    private_dns_zone_ids = [module.network.private_dns_zone_ids["privatelink.vaultcore.azure.net"]]
  }
}

resource "azurerm_private_endpoint" "eventhub_namespace" {
  count = var.enable_private_endpoints && var.enable_runtime_alerting ? 1 : 0

  name                = "${var.name_prefix}-falco-eh-pe"
  location            = module.network.location
  resource_group_name = module.network.resource_group_name
  subnet_id           = module.network.private_endpoints_subnet_id
  tags                = local.tags

  private_service_connection {
    name                           = "falco-eventhub"
    private_connection_resource_id = module.falco_alerting[0].eventhub_namespace_id
    subresource_names              = ["namespace"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "eventhub-dns"
    private_dns_zone_ids = [module.network.private_dns_zone_ids["privatelink.servicebus.windows.net"]]
  }
}

resource "azurerm_private_endpoint" "function_storage_blob" {
  count = var.enable_private_endpoints && var.enable_runtime_alerting ? 1 : 0

  name                = "${var.name_prefix}-falco-fn-blob-pe"
  location            = module.network.location
  resource_group_name = module.network.resource_group_name
  subnet_id           = module.network.private_endpoints_subnet_id
  tags                = local.tags

  private_service_connection {
    name                           = "falco-function-storage-blob"
    private_connection_resource_id = module.falco_alerting[0].function_storage_account_id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "function-storage-blob-dns"
    private_dns_zone_ids = [module.network.private_dns_zone_ids["privatelink.blob.core.windows.net"]]
  }
}

# The Functions host uses identity-based AzureWebJobsStorage, which requires
# Blob, Queue, and Table services. All three subresources get private
# endpoints so stage-3 closure (public storage access disabled) keeps the
# host fully operational without storage keys or connection strings.
resource "azurerm_private_endpoint" "function_storage_queue" {
  count = var.enable_private_endpoints && var.enable_runtime_alerting ? 1 : 0

  name                = "${var.name_prefix}-falco-fn-queue-pe"
  location            = module.network.location
  resource_group_name = module.network.resource_group_name
  subnet_id           = module.network.private_endpoints_subnet_id
  tags                = local.tags

  private_service_connection {
    name                           = "falco-function-storage-queue"
    private_connection_resource_id = module.falco_alerting[0].function_storage_account_id
    subresource_names              = ["queue"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "function-storage-queue-dns"
    private_dns_zone_ids = [module.network.private_dns_zone_ids["privatelink.queue.core.windows.net"]]
  }
}

resource "azurerm_private_endpoint" "function_storage_table" {
  count = var.enable_private_endpoints && var.enable_runtime_alerting ? 1 : 0

  name                = "${var.name_prefix}-falco-fn-table-pe"
  location            = module.network.location
  resource_group_name = module.network.resource_group_name
  subnet_id           = module.network.private_endpoints_subnet_id
  tags                = local.tags

  private_service_connection {
    name                           = "falco-function-storage-table"
    private_connection_resource_id = module.falco_alerting[0].function_storage_account_id
    subresource_names              = ["table"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "function-storage-table-dns"
    private_dns_zone_ids = [module.network.private_dns_zone_ids["privatelink.table.core.windows.net"]]
  }
}
