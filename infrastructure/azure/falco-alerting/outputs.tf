output "eventhub_id" {
  description = "Resource ID of the Event Hub that receives Falco alerts."
  value       = azurerm_eventhub.falco_alerts.id
}

output "eventhub_name" {
  description = "Name of the Falco Event Hub."
  value       = azurerm_eventhub.falco_alerts.name
}

output "eventhub_namespace_fqdn" {
  description = "Fully qualified namespace consumed by Falcosidekick."
  value       = "${azurerm_eventhub_namespace.falco.name}.servicebus.windows.net"
}

output "eventhub_namespace_id" {
  description = "Resource ID of the Falco Event Hubs namespace for private endpoints."
  value       = azurerm_eventhub_namespace.falco.id
}

output "key_vault_id" {
  description = "Resource ID of the alerting Key Vault for private endpoints."
  value       = azurerm_key_vault.falco.id
}

output "function_storage_account_id" {
  description = "Resource ID of the Function host storage account for private endpoints."
  value       = azurerm_storage_account.function.id
}

output "falcosidekick_client_id" {
  description = "Client ID to pass to the Falcosidekick Helm chart for AKS Workload Identity."
  value       = azurerm_user_assigned_identity.falcosidekick.client_id
}

output "function_name" {
  description = "Name of the Azure Function that forwards Falco alerts to Discord."
  value       = azurerm_linux_function_app.discord_notifier.name
}

output "key_vault_uri" {
  description = "Key Vault URI holding the Discord webhook."
  value       = azurerm_key_vault.falco.vault_uri
}
