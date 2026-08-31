# Azure workload network

This reusable module creates the network boundary used by the Azure
implementation: a workload resource group, VNet, separate AKS node/API-server
subnets, a private-endpoint subnet, a Functions VNet-integration subnet, NSGs,
a Standard NAT Gateway, and Private Link DNS zones.

The default address plan mirrors the existing GCP separation without reusing
the VNet range for pods or services:

| Purpose | Default range |
|---|---|
| VNet | `10.0.0.0/16` |
| AKS VMSS nodes | `10.0.0.0/20` |
| AKS API Server VNet Integration | `10.0.16.0/28` |
| Private Endpoints | `10.0.32.0/24` |
| Azure Functions VNet Integration | `10.0.48.0/24` |
| AKS Azure CNI Overlay pods (configured by AKS module) | `10.4.0.0/14` |
| AKS services (configured by AKS module) | `10.8.0.0/20` |

Validate the full estate for overlap before apply; Terraform can validate CIDR
syntax but cannot prove that independently supplied ranges do not overlap.

## Use

The calling Azure environment configures the provider and invokes the module:

```hcl
module "network" {
  source = "../../network"

  resource_group_name = "rg-supply-chain-prod"
  location            = "centralindia"
  vnet_name           = "vnet-supply-chain-prod"

  environment   = "prod"
  owner         = "platform-security"
  project_label = "supply-chain-security"
  cost_center   = "security"
}
```

Pass `module.network.aks_nodes_subnet_id`,
`module.network.aks_api_server_subnet_id`, and `module.network.vnet_id` to the
AKS module. The AKS module gives its control-plane managed identity Network
Contributor at the VNet scope before cluster creation.

## DNS and private access

The module creates and links Private Link zones for ACR, Blob Storage, Event
Hubs/Service Bus, and Key Vault. Later modules create the private endpoints
and corresponding zone groups. AKS defaults to Azure-managed (`System`) private
DNS for its API server; a runner outside this VNet still needs a suitable
private-DNS forwarding/link design and routed network access to use `kubectl`.

## Flow logs

Azure retired new NSG flow-log creation, so this module targets VNet flow logs
when `enable_flow_logs = true`. It is off by default because availability and
Network Watcher permissions vary by subscription. The flow-log storage account
is dedicated: the Terraform resource creates a lifecycle rule that can replace
an existing rule on a reused account. Do not share it with state or workload
data.
