# Azure production environment root

Composes the Azure implementation in dependency order. Nothing here invents
Azure values: region, ACR name, Entra groups, and the Discord webhook (if ever
used) come from the owner, and all placeholders are marked `REPLACE_*`.

```text
network (NAT/DNS/optional flow logs) -> aks (daily maintenance) ->
supply-chain -> kubernetes-addons (Kyverno/Argo CD) -> falco <- falco-alerting
```

## Prerequisites

1. Run `infrastructure/azure/bootstrap-state` first and copy its `backend_config`
   output into the `terraform init -backend-config=...` invocation below.
2. The applying principal needs permissions to create resource groups,
   networking, AKS, managed identities, federated credentials, ACR, role
   assignments, Log Analytics, Storage, Key Vault, Event Hubs, and Functions.
3. Terraform >= 1.11 and `kubelogin` on the PATH of the private-network host.

## Staged apply

The cluster API is private, so Helm/Kubernetes stages must run from a host
that can route to the workload VNet and resolve the private API FQDN.

### Stage 1 — foundation (any host with Azure network egress to the APIs)

```bash
terraform init \
  -backend-config='resource_group_name=REPLACE_STATE_RESOURCE_GROUP' \
  -backend-config='storage_account_name=REPLACE_STATE_STORAGE_ACCOUNT' \
  -backend-config='container_name=tfstate' \
  -backend-config='key=azure-supply-chain-security/prod.tfstate' \
  -backend-config='use_azuread_auth=true'
terraform plan -out stage1.tfplan
terraform apply stage1.tfplan
```

With the default gates (`enable_workload_addons = false`,
`enable_runtime_alerting = false`, `enable_private_endpoints = false`) stage 1
creates network, private AKS, and the ACR/supply-chain identities. VNet flow
logs stay disabled unless the owner supplies a dedicated storage account name.
No Helm or Kubernetes resource is evaluated.

### Stage 2 — core admission and runtime (private-network host only)

Resolve the private API FQDN (output `private_fqdn`) from the operator host,
then set `enable_workload_addons = true` and apply one saved plan from that
private host. The add-ons module installs Kyverno, waits for its CRDs, installs
the rendered ClusterPolicy through a dependent local Helm chart, installs the
pinned private Argo CD foundation, and installs Falco in the same Terraform
apply. Keep `enable_runtime_alerting = false` unless
`TF_VAR_discord_webhook_url` is explicitly supplied through the write-only
Key Vault path.

### Stage 3 — private closure

After confirming private DNS resolution and runner connectivity, set
`enable_private_endpoints = true` and apply. This creates Private Endpoints
for the registry (registry + data), Key Vault, Event Hubs, and the Function
host storage account (**Blob, Queue, and Table** — the services the
identity-based `AzureWebJobsStorage` requires), and flips every child module's
public network flag to false. Verify the `registry_public_access_enabled`
output is `false` before promoting releases.

Before accepting stage-3 closure, confirm from inside the workload VNet that
private DNS resolves all storage endpoints (`*.blob.core.windows.net`,
`*.queue.core.windows.net`, `*.table.core.windows.net` for the Function
storage account) and that the Function host starts and operates correctly
(deployment package read, host queue operations, and table-based instance
management) using only its managed identity. Do not accept closure while any
of the three services is unreachable.

## GitHub configuration

Set repository variables (never secrets) from the outputs:

| Variable | Output |
|---|---|
| `AZURE_CLIENT_ID` | `github_ci_client_id` |
| `AZURE_TENANT_ID` | `tenant_id` |
| `AZURE_SUBSCRIPTION_ID` | `subscription_id` |
| `ACR_LOGIN_SERVER` | `acr_login_server` |
| `ACR_REPOSITORY` | `application_image_repository` |
| `COSIGN_REPOSITORY` | `cosign_metadata_repository` |

The GitHub CI federated credential trusts only
`repo:devSatym/gcp-supply-chain-security:ref:refs/heads/main`.

## AKS deployment authority

The production root retains narrowly scoped AKS roles for an owner-approved
private deployment fallback. The current Azure workflow does not use them:
promotion is a read-only artifact and Argo CD is the in-cluster release
controller. If an imperative private-runner path is separately approved, its
identity is exactly:

- `Azure Kubernetes Service Cluster User Role` at the private cluster scope —
  permits `az aks get-credentials` to obtain the non-admin user kubeconfig;
- `Azure Kubernetes Service RBAC Writer` scoped to
  `<cluster-id>/namespaces/default` only — matches the Helm release namespace.

No cluster-admin, Contributor, or resource-group-wide deployment authority is
granted. Both role assignments are exported
(`github_ci_aks_cluster_user_role_assignment_id`,
`github_ci_aks_default_namespace_writer_role_assignment_id`). Live
confirmation that these scopes are sufficient for the private-runner Helm
deployment remains required and is tracked in
`docs/azure/04-live-validation-checklist.md`.

## Release promotion

Build, scan, sign, attest, verify, and lock run in `azure-deploy.yml`; the
main-only `promote` job renders the verified digest into
`values.release.yaml` and a manifest artifact with `contents: read`
only. Add that file through an owner-reviewed GitOps change before enabling
Argo automatic sync. The base chart values and
`values.release.yaml.example` are intentionally non-deployable
placeholders.

## GCP parity controls

- VNet flow logs are implemented through Azure Network Watcher and a dedicated
  StorageV2 account. They are opt-in because the account name is globally
  unique and subscription support/permissions must be confirmed first.
- AKS uses a daily four-hour maintenance window beginning at 03:00 UTC and
  the `NodeImage` OS upgrade channel, matching the active GKE daily window.
- Falco loads the active CRITICAL shell-spawn rule from
  `infrastructure/azure/falco/custom-rules.yaml`; Azure control-plane
  namespaces are excluded while `default` remains enforced.
- Argo CD is installed with a pinned chart, ClusterIP-only server, no ingress,
  no Dex/notifications/HA Redis, and the reviewed digest file as its only
  release override.
