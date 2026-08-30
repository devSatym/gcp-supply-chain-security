# Private Azure Kubernetes Service

This reusable module creates a private AKS cluster for the Azure supply-chain
security implementation. It preserves the GKE security posture with Azure
equivalents:

- Azure CNI Overlay using dedicated pod and service CIDRs;
- private API server with API Server VNet Integration and no public API access;
- Microsoft Entra-managed AKS authentication with Azure RBAC and local
  accounts disabled;
- OIDC issuer and Azure Workload Identity for later Kyverno/Falcosidekick
  identities;
- autoscaled VMSS system and user node pools with no node public IPs;
- a user-assigned control-plane identity granted `Network Contributor` before
  AKS creation;
- Container Insights backed by a dedicated Log Analytics workspace; and
- optional least-privilege ACR pull permission for the AKS **kubelet** identity.

## Network prerequisites

Create the network module first and pass its outputs:

```hcl
module "aks" {
  source = "../../aks"

  resource_group_name  = module.network.resource_group_name
  location             = module.network.location
  cluster_name         = "aks-supply-chain-prod"
  network_scope_id     = module.network.vnet_id
  node_subnet_id       = module.network.aks_nodes_subnet_id
  api_server_subnet_id = module.network.aks_api_server_subnet_id

  system_node_pool = {
    name         = "system"
    vm_size      = "Standard_D4s_v5"
    min_size     = 2
    max_size     = 5
    desired_size = 2
  }

  environment   = "prod"
  owner         = "platform-security"
  project_label = "supply-chain-security"
  cost_center   = "security"
}
```

The identity applying this module must be able to create the control-plane
managed identity and assign `Network Contributor` at the supplied VNet scope.
It also needs normal AKS, Log Analytics, and role-assignment permissions.

## Private access and Kubernetes authorization

The Kubernetes API has no public endpoint. Terraform Helm/Kubernetes providers
and `az aks get-credentials` therefore must run from a host that can route to
the VNet and resolve the private API FQDN. Do not enable public access to make
GitHub-hosted runners work; use a controlled private runner instead.

Grant human and automation access using AKS Azure RBAC roles assigned to Entra
groups. `azure_rbac_admin_group_object_ids` is only the initial administrator
set; it is not a replacement for scoped operational roles.

## Workload identity

The module enables the cluster-side prerequisites only. Later modules must
create a dedicated user-assigned managed identity and
`azurerm_federated_identity_credential` for each Kubernetes service account,
using `oidc_issuer_url`, audience `api://AzureADTokenExchange`, and a subject
such as `system:serviceaccount:namespace:service-account`. The service account
must be annotated with its identity client ID and its Pods must carry the
`azure.workload.identity/use: "true"` label.

## ACR pull access

Set `acr_id` only after the registry exists. The module then grants the role
named by `acr_pull_role_definition_name` to the AKS kubelet identity. `AcrPull`
is the non-ABAC default. The planned ACR `rbac-abac` configuration needs the
repository-reader role/condition chosen by the registry module; retain
digest-only deployments regardless of the pull role.
