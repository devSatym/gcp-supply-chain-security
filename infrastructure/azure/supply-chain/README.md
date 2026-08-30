# Azure supply-chain foundation

This module creates the Azure registry and managed identities used by the
Azure implementation. It is additive: it neither imports nor changes the GCP
implementation.

It creates:

- a Premium Azure Container Registry in `AbacRepositoryPermissions` mode;
- a GitHub CI user-assigned managed identity (UAMI), trusted only for the
  canonical repository's `refs/heads/main` GitHub OIDC subject;
- a Kyverno UAMI, trusted only for the configured AKS ServiceAccount subject;
- repository-scoped ACR writer/reader role assignments for both the
  application and separate Cosign metadata paths; and
- optional repository-scoped pull access for an AKS kubelet identity supplied
  by the AKS module.

It deliberately does **not** create a Falcosidekick identity. That identity
belongs to `falco-alerting`, where it can be scoped to a specific Event Hubs
sender resource.

## Trust model

The GitHub federated credential is intentionally fixed to:

```text
issuer:  https://token.actions.githubusercontent.com
subject: repo:devSatym/gcp-supply-chain-security:ref:refs/heads/main
audience: api://AzureADTokenExchange
```

This feature branch can run static validation but cannot gain Azure production
authority merely by changing its branch name. Do not change this subject unless
the repository owner explicitly approves a different protected release branch
and updates the complete trust chain together.

Kyverno's federated credential uses the AKS OIDC issuer and exactly this
subject shape:

```text
system:serviceaccount:<kyverno_namespace>:<kyverno_service_account_name>
```

The Kyverno Helm values must annotate that ServiceAccount with the emitted
`kyverno_client_id` and label its admission-controller Pods for Azure Workload
Identity.

## ACR repository design

ACR repositories are materialized by the first push; Terraform does not create
empty repository resources. This module therefore grants access at the ACR
scope with ABAC conditions that restrict each role assignment to these exact
repository names:

```text
supply-chain-security/supply-chain-demo
supply-chain-security-attestations/supply-chain-demo
```

The second value is exported as `cosign_metadata_repository`. Configure it as
`COSIGN_REPOSITORY` in the Azure signing and verification workflows. It is a
separate mutable location for legacy Cosign signature and attestation indexes.
The design does not rely on ACR native OCI referrers.

`Container Registry Repository Catalog Lister` is deliberately disabled by
default. It is registry-wide and neither Docker push nor Kyverno verification
needs catalog enumeration when both repository names are already known. Enable
one of the dedicated opt-in variables only after a tested client proves it
requires listing.

ACR lacks GAR's immutable-tag repository setting. The Azure CI workflow must,
after successful scan/sign/attest/verify, lock the promoted manifest digest
with `az acr repository update --write-enabled false --delete-enabled false`.
Deployments are digest-pinned and Kyverno enforces `verifyDigest`, so the
digest lock is the binding control; never lock the Cosign metadata repository.

## Usage

```hcl
module "supply_chain" {
  source = "../../supply-chain"

  resource_group_name = azurerm_resource_group.prod.name
  location            = azurerm_resource_group.prod.location
  name_prefix         = "supplychain-prod"
  acr_name            = "supplychainprodacr"
  aks_oidc_issuer_url = module.aks.oidc_issuer_url

  # Optional until AKS has been created. Pass this in the environment root so
  # AKS nodes can pull the digest-pinned application without imagePullSecrets.
  aks_kubelet_principal_id = module.aks.kubelet_identity_object_id

  tags = {
    environment = "prod"
    owner       = "platform-team"
    project     = "supply-chain-security"
    cost_center = "engineering"
  }
}
```

The caller needs Azure permissions to create managed identities, federated
credentials, ACR, and role assignments. ACR is configured with admin and
anonymous access disabled. Authenticated public network access is an explicit
input, initially enabled for the known GitHub CI path; set it to `false` only
after private endpoints, private DNS, and a private-capable CI runner exist.

## Key outputs

| Output | Consumer |
|---|---|
| `acr_login_server` | Azure Docker login and Kubernetes image paths |
| `application_image_repository` | CI image reference and digest-pinned Helm values |
| `cosign_metadata_repository` | `COSIGN_REPOSITORY` in signing/verification workflows |
| `github_ci_client_id` | `azure/login` in trusted main-branch CI |
| `kyverno_client_id` | Kyverno ServiceAccount workload-identity annotation |

## Validation

```bash
terraform -chdir=infrastructure/azure/supply-chain fmt -check -recursive
terraform -chdir=infrastructure/azure/supply-chain init -backend=false
terraform -chdir=infrastructure/azure/supply-chain validate
```

`validate` checks Terraform syntax and provider schemas only; a live plan
requires supplied Azure subscription, tenant, resource group, and AKS OIDC
issuer values.
