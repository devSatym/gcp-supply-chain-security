# Azure infrastructure

The active Terraform implementation is under [`azure/`](azure/). It has two
separate state domains:

- `azure/bootstrap-state` owns the encrypted Azure Blob backend and optional
  state private endpoint.
- `azure/environments/prod` owns the private AKS workload, ACR, identities,
  private runner, Kyverno, Argo CD, Falco, and optional alerting plane.

The production root uses an `azurerm` remote backend only. Its wrapper creates
all Terraform data, plans, and logs in a temporary directory and rejects
destructive plans. The GitHub convergence workflow authenticates with a
dedicated main-only OIDC managed identity; it has Blob data access to state,
workload-scoped Contributor/User Access Administrator, and AKS cluster-admin
only where Terraform needs it.

Run [the root startup guide](../README.md#one-time-startup) before using
`scripts/azure/apply-once.sh`.
