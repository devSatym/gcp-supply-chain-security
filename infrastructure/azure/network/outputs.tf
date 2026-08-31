output "resource_group_id" {
  description = "ID of the workload resource group."
  value       = azurerm_resource_group.workload.id
}

output "resource_group_name" {
  description = "Name of the workload resource group for dependent Azure modules."
  value       = azurerm_resource_group.workload.name
}

output "location" {
  description = "Azure region shared by the workload resource group and VNet."
  value       = azurerm_resource_group.workload.location
}

output "vnet_id" {
  description = "ID of the workload VNet. Pass this as network_scope_id to the AKS module."
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Name of the workload VNet."
  value       = azurerm_virtual_network.main.name
}

output "aks_nodes_subnet_id" {
  description = "ID of the non-delegated subnet for AKS managed node pools."
  value       = azurerm_subnet.aks_nodes.id
}

output "aks_subnet_id" {
  description = "Compatibility alias for the non-delegated AKS node-pool subnet ID."
  value       = azurerm_subnet.aks_nodes.id
}

output "aks_api_server_subnet_id" {
  description = "ID of the delegated subnet for AKS API Server VNet Integration."
  value       = azurerm_subnet.aks_api_server.id
}

output "private_endpoints_subnet_id" {
  description = "ID of the subnet reserved for Azure Private Endpoints."
  value       = azurerm_subnet.private_endpoints.id
}

output "private_endpoint_subnet_id" {
  description = "Compatibility alias for the subnet reserved for Azure Private Endpoints."
  value       = azurerm_subnet.private_endpoints.id
}

output "functions_subnet_id" {
  description = "ID of the delegated subnet for Azure Functions VNet Integration."
  value       = azurerm_subnet.functions.id
}

output "private_runner_subnet_id" {
  description = "ID of the no-public-IP subnet reserved for the GitHub Actions runner."
  value       = azurerm_subnet.private_runner.id
}

output "function_subnet_id" {
  description = "Compatibility alias for the Azure Functions VNet Integration subnet ID."
  value       = azurerm_subnet.functions.id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway attached to the AKS node subnet."
  value       = azurerm_nat_gateway.main.id
}

output "nat_public_ip_address" {
  description = "Controlled egress IP address used by AKS nodes and, by default, Functions."
  value       = azurerm_public_ip.nat.ip_address
}

output "private_dns_zone_ids" {
  description = "Map of Private Link DNS zone names to resource IDs for later private-endpoint modules."
  value       = { for name, zone in azurerm_private_dns_zone.private_link : name => zone.id }
}

output "network_security_group_ids" {
  description = "NSG IDs for the AKS node, Functions, and Private Endpoint subnets."
  value = {
    aks_nodes         = azurerm_network_security_group.aks_nodes.id
    functions         = azurerm_network_security_group.functions.id
    private_endpoints = azurerm_network_security_group.private_endpoints.id
    private_runner    = azurerm_network_security_group.private_runner.id
  }
}

output "flow_log_id" {
  description = "VNet flow-log resource ID when enable_flow_logs is true; otherwise null."
  value       = try(azurerm_network_watcher_flow_log.vnet[0].id, null)
}

output "flow_logs_storage_account_id" {
  description = "Dedicated VNet flow-log storage account ID when flow logs are enabled; otherwise null."
  value       = try(azurerm_storage_account.flow_logs[0].id, null)
}
