output "resource_group_name" {
  description = "Name of the dedicated Terraform state resource group."
  value       = azurerm_resource_group.state.name
}

output "storage_account_id" {
  description = "Resource ID of the state storage account."
  value       = azurerm_storage_account.state.id
}

output "storage_account_name" {
  description = "Name of the state storage account for azurerm backend configuration."
  value       = azurerm_storage_account.state.name
}

output "container_name" {
  description = "Private Blob container that stores state files."
  value       = azurerm_storage_container.state.name
}

output "state_key" {
  description = "Suggested production state key for the azurerm backend."
  value       = var.state_key
}

output "backend_config" {
  description = "Non-secret azurerm backend settings. Supply identity settings through ARM_* environment variables rather than Terraform files."
  value = {
    resource_group_name  = azurerm_resource_group.state.name
    storage_account_name = azurerm_storage_account.state.name
    container_name       = azurerm_storage_container.state.name
    key                  = var.state_key
    use_azuread_auth     = true
    use_oidc             = true
  }
}

output "private_endpoint_id" {
  description = "Resource ID of the optional state Blob Private Endpoint."
  value       = try(azurerm_private_endpoint.state_blob[0].id, null)
}

output "blob_endpoint" {
  description = "Blob service endpoint hostname for private DNS and connectivity checks."
  value       = azurerm_storage_account.state.primary_blob_endpoint
}
