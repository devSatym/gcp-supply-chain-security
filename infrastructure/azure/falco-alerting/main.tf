# Falco -> Falcosidekick -> Event Hubs -> Azure Functions -> Key Vault -> Discord.
#
# This module is invoked only when runtime alerting is explicitly enabled by
# the production root. It uses managed identities end-to-end: Falcosidekick
# publishes with an AKS workload identity and the Function reads Event Hubs,
# its host storage, and the Discord webhook with its system-assigned identity.

data "azurerm_client_config" "current" {}

locals {
  eventhub_namespace_name = "${var.name_prefix}-falco-eh"
  function_storage_name   = "${var.name_prefix}falcofn"
  key_vault_name          = "${var.name_prefix}-falco-kv"
  function_name           = "${var.name_prefix}-falco-discord"
  function_source_dir     = coalesce(var.function_source_dir, "${path.module}/functions/discord-notifier")
}

resource "azurerm_eventhub_namespace" "falco" {
  name                          = local.eventhub_namespace_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = "Standard"
  capacity                      = 1
  auto_inflate_enabled          = false
  local_authentication_enabled  = false
  public_network_access_enabled = var.public_network_access_enabled
  minimum_tls_version           = "1.2"
  tags                          = var.tags
}

resource "azurerm_eventhub" "falco_alerts" {
  name                = var.eventhub_name
  namespace_name      = azurerm_eventhub_namespace.falco.name
  resource_group_name = var.resource_group_name
  partition_count     = 2
  message_retention   = 1
}

resource "azurerm_user_assigned_identity" "falcosidekick" {
  name                = "${var.name_prefix}-falcosidekick"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "falcosidekick" {
  name                = "falcosidekick-aks"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.falcosidekick.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.aks_oidc_issuer_url
  subject             = var.falcosidekick_service_account_subject
}

resource "azurerm_role_assignment" "falcosidekick_eventhub_sender" {
  scope                = azurerm_eventhub.falco_alerts.id
  role_definition_name = "Azure Event Hubs Data Sender"
  principal_id         = azurerm_user_assigned_identity.falcosidekick.principal_id
  principal_type       = "ServicePrincipal"
}

# The webhook itself is write-only in Terraform state. Key Vault RBAC, rather
# than an access policy, is used so the Function has exactly Secrets User.
resource "azurerm_key_vault" "falco" {
  name                          = local.key_vault_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 7
  public_network_access_enabled = var.public_network_access_enabled
  tags                          = var.tags
}

resource "azurerm_key_vault_secret" "discord_webhook" {
  name             = "falco-discord-webhook-url"
  key_vault_id     = azurerm_key_vault.falco.id
  value_wo         = var.discord_webhook_url
  value_wo_version = var.discord_webhook_secret_version
  content_type     = "Discord webhook URL"
  tags             = var.tags
}

resource "azurerm_storage_account" "function" {
  name                            = local.function_storage_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  public_network_access_enabled   = var.public_network_access_enabled
  tags                            = var.tags
}

resource "azurerm_service_plan" "function" {
  name                = "${var.name_prefix}-falco-functions"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "Y1"
  tags                = var.tags
}

data "archive_file" "discord_notifier" {
  type        = "zip"
  source_dir  = local.function_source_dir
  output_path = "${path.module}/.build/discord-notifier.zip"
}

resource "azurerm_linux_function_app" "discord_notifier" {
  name                          = local.function_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  service_plan_id               = azurerm_service_plan.function.id
  storage_account_name          = azurerm_storage_account.function.name
  storage_uses_managed_identity = true
  https_only                    = true
  zip_deploy_file               = data.archive_file.discord_notifier.output_path

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = "3.12"
    }
  }

  app_settings = {
    FUNCTIONS_EXTENSION_VERSION                 = "~4"
    FUNCTIONS_WORKER_RUNTIME                    = "python"
    AzureWebJobsStorage__accountName            = azurerm_storage_account.function.name
    AzureWebJobsStorage__credential             = "managedidentity"
    EventHubConnection__fullyQualifiedNamespace = "${azurerm_eventhub_namespace.falco.name}.servicebus.windows.net"
    EventHubConnection__credential              = "managedidentity"
    EVENT_HUB_NAME                              = azurerm_eventhub.falco_alerts.name
    KEY_VAULT_URI                               = azurerm_key_vault.falco.vault_uri
    DISCORD_WEBHOOK_SECRET_NAME                 = azurerm_key_vault_secret.discord_webhook.name
    MIN_PRIORITY                                = lower(var.minimum_priority)
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "function_eventhub_receiver" {
  scope                = azurerm_eventhub.falco_alerts.id
  role_definition_name = "Azure Event Hubs Data Receiver"
  principal_id         = azurerm_linux_function_app.discord_notifier.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "function_key_vault_secrets_user" {
  scope                = azurerm_key_vault.falco.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_function_app.discord_notifier.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

# Identity-based Azure Functions host storage needs data-plane blob and queue
# access; Storage Account Contributor permits the host to discover account
# metadata without granting account keys.
resource "azurerm_role_assignment" "function_storage_blob_owner" {
  scope                = azurerm_storage_account.function.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_linux_function_app.discord_notifier.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "function_storage_queue_contributor" {
  scope                = azurerm_storage_account.function.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_linux_function_app.discord_notifier.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "function_storage_account_contributor" {
  scope                = azurerm_storage_account.function.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = azurerm_linux_function_app.discord_notifier.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}
