output "workspace_id" {
  description = "Resource ID of the Azure Log Analytics workspace receiving AKS and ACR diagnostics."
  value       = azurerm_log_analytics_workspace.this.id
}

output "workspace_name" {
  description = "Name of the Azure Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.this.name
}
