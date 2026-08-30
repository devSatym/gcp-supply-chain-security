output "cluster_id" {
  description = "Resource ID of the private AKS cluster."
  value       = azurerm_kubernetes_cluster.main.id
}

output "id" {
  description = "Compatibility alias for the private AKS cluster resource ID."
  value       = azurerm_kubernetes_cluster.main.id
}

output "cluster_name" {
  description = "Name of the private AKS cluster."
  value       = azurerm_kubernetes_cluster.main.name
}

output "name" {
  description = "Compatibility alias for the private AKS cluster name."
  value       = azurerm_kubernetes_cluster.main.name
}

output "resource_group_name" {
  description = "Workload resource group containing the private AKS cluster."
  value       = var.resource_group_name
}

output "location" {
  description = "Azure region containing the private AKS cluster."
  value       = var.location
}

output "host" {
  description = "Private Kubernetes API host. A connected private runner and private DNS are required to reach it."
  value       = "https://${azurerm_kubernetes_cluster.main.private_fqdn}"
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64-encoded Kubernetes API CA certificate for provider configuration."
  value       = azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate
  sensitive   = true
}

output "private_fqdn" {
  description = "Private Kubernetes API FQDN. It is resolvable only from correctly connected private DNS networks."
  value       = azurerm_kubernetes_cluster.main.private_fqdn
}

output "portal_fqdn" {
  description = "Private Azure Portal AKS FQDN when supplied by Azure."
  value       = azurerm_kubernetes_cluster.main.portal_fqdn
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL used by later Azure Workload Identity federated credentials."
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

output "control_plane_identity" {
  description = "User-assigned control-plane managed identity for diagnostics and least-privilege role review."
  value = {
    id           = azurerm_user_assigned_identity.control_plane.id
    client_id    = azurerm_user_assigned_identity.control_plane.client_id
    principal_id = azurerm_user_assigned_identity.control_plane.principal_id
  }
}

output "kubelet_identity" {
  description = "AKS-managed kubelet identity. Later ACR and Azure resource permissions must target this identity, not the control-plane identity."
  value = {
    client_id                 = azurerm_kubernetes_cluster.main.kubelet_identity[0].client_id
    object_id                 = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
    user_assigned_identity_id = azurerm_kubernetes_cluster.main.kubelet_identity[0].user_assigned_identity_id
  }
}

output "kubelet_identity_object_id" {
  description = "Object ID of the AKS kubelet managed identity for ACR pull and other node-level Azure role assignments."
  value       = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

output "log_analytics_workspace" {
  description = "Log Analytics workspace used by Container Insights."
  value = {
    id           = azurerm_log_analytics_workspace.aks.id
    name         = azurerm_log_analytics_workspace.aks.name
    workspace_id = azurerm_log_analytics_workspace.aks.workspace_id
  }
}

output "node_pool_names" {
  description = "Names of the managed system and user node pools."
  value = merge(
    { system = azurerm_kubernetes_cluster.main.default_node_pool[0].name },
    { for key, pool in azurerm_kubernetes_cluster_node_pool.user : key => pool.name },
  )
}

output "get_credentials_command" {
  description = "Azure CLI command for a private-network-capable operator to obtain Entra-authenticated kubeconfig."
  value       = "az aks get-credentials --resource-group ${var.resource_group_name} --name ${azurerm_kubernetes_cluster.main.name} --overwrite-existing"
}
