# Azure production environment root

Composes the Azure implementation in dependency order. Nothing here invents
Azure values: region, ACR name, Entra groups, and the Discord webhook (if ever
used) come from the owner, and all placeholders are marked `REPLACE_*`.

```text
network (NAT/DNS/optional flow logs) -> aks (daily maintenance) ->
supply-chain -> kubernetes-addons (Kyverno/Argo CD) -> falco <- falco-alerting
```

## Prerequisites

1. Run `infrastructure/azure/bootstrap-state` once and provide its remote Blob
   backend through `--backend-config` or the `TFSTATE_*` environment variables.
2. The applying principal needs permissions to create resource groups,
   networking, AKS, managed identities, federated credentials, ACR, role
   assignments, Log Analytics, Storage, Key Vault, Event Hubs, and Functions.
3. Terraform >= 1.11 and `kubelogin` on the PATH of the private-network host.
4. The applying host must resolve and reach the private AKS API. Private mode
   additionally requires an owner-approved private GitHub runner before ACR
   public access can be closed.

## One-command convergence

Run this from the private-network-capable operator host. It initializes the
existing remote backend, creates saved plans outside the repository, applies
the foundation, verifies private AKS DNS/443, and converges add-ons/Argo/Falco:

```bash
scripts/azure/apply-once.sh --mode core
```

`core` leaves ACR and optional alerting services authenticated but publicly
reachable for hosted GitHub release jobs. AKS is private in both modes.

For the fully private service path, provide the explicit runner acknowledgement:

```bash
PRIVATE_GITHUB_RUNNER_READY=true scripts/azure/apply-once.sh --mode private
```

The runner creates endpoints with public access still enabled, probes the ACR
registry/data paths and every enabled alerting path, and only then applies the
separate `disable_public_network_access=true` closure. It never asks the
operator to hand-edit Terraform flags between phases.

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
| `ACR_REPOSITORY` | `application_repository` |
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

Build, scan, sign, attest, verify, and lock run in `azure-deploy.yml`. The
main-only `promote` job has the only `contents: write` permission, renders the
verified digest into `values.release.yaml`, verifies that only that file
changed, and pushes it to `main`. The private Argo Application automatically
reconciles the file; the base chart remains inert until that verified release
exists. Promotion never calls Azure, Helm, or `kubectl`.

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
