output "id" {
  description = "Resource ID of the private runner VM."
  value       = azurerm_linux_virtual_machine.this.id
}

output "name" {
  description = "Name of the private runner VM used by Azure Run Command."
  value       = azurerm_linux_virtual_machine.this.name
}

output "private_ip_address" {
  description = "Private IP address of the runner VM."
  value       = azurerm_network_interface.this.private_ip_address
}

output "principal_id" {
  description = "System-assigned managed identity principal ID of the runner VM."
  value       = azurerm_linux_virtual_machine.this.identity[0].principal_id
}
