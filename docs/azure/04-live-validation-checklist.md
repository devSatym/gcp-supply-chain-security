# 04 — Live validation checklist

Status vocabulary:

- `STATICALLY_VALIDATED` — proven by the offline checks recorded in
  `03-validation-checklist.md`.
- `LIVE_VALIDATION_PENDING` — implemented, but requires the real Azure
  environment and the external inputs below. Items not explicitly marked live
  validated have not been closed with Azure evidence.
- `LIVE_VALIDATED` — performed against real Azure with Azure-only evidence
  recorded beside the item.

Core items marked below are historical `LIVE_VALIDATED` evidence from the
private jump VM on 2026-08-30. On 2026-08-31, the authenticated subscription
reported both the workload and state resource groups as absent, and this host
could not resolve the previously configured private Blob endpoint. The live
environment must therefore be reprovisioned or restored and revalidated; no
fresh deployment is claimed here. Do not reuse GCP evidence as Azure evidence.

## Current live status

| Area | Status | Evidence |
| --- | --- | --- |
| Current subscription/resource availability | `LIVE_VALIDATION_PENDING` | 2026-08-31 `az group show` reported the configured workload and state groups as not found; a private runner/host is still required. |
| Terraform state private access | `LIVE_VALIDATED` | VM managed identity read the remote state through Blob Private Link; shared keys and public state access are disabled. |
| Private AKS | `LIVE_VALIDATED` | AKS is `Succeeded`, private, and the one-node pool is Ready. |
| AKS maintenance parity | `LIVE_VALIDATED` | Both managed maintenance schedules are present with a daily 03:00 UTC window; node-image upgrades remain selected. |
| Kyverno + ClusterPolicy | `LIVE_VALIDATED` | One saved plan added the Helm releases; policy action is `Enforce` and all three trust rules are present. |
| Falco runtime sensor + custom rule | `LIVE_VALIDATED` | Falco daemonset and metadata collector are Ready; the Azure custom shell-spawn rule is present in the release values. |
| Argo CD foundation | `LIVE_VALIDATED` | Pinned chart is installed privately; server and supporting services are Running with ClusterIP services and no ingress. |
| Mutable application tag rejection | `LIVE_VALIDATED` | A server-side dry-run Pod using `supply-chain-demo:latest` was denied by all three trust rules from the private jump VM. |
| Trusted Azure image release | `LIVE_VALIDATION_PENDING` | Workflow and GitHub variables are configured in the owner repository, but a fresh main-branch run must follow infrastructure restoration. |
| Demo workload | `LIVE_VALIDATION_PENDING` | Requires a verified and locked ACR digest. |
| Discord alerting | `BLOCKED_BY_EXTERNAL_INPUT` | No webhook is configured; alerting remains intentionally disabled. |
| Private ACR closure | `BLOCKED_BY_EXTERNAL_INPUT` | Requires a private GitHub runner with VNet/private-DNS access and restored Azure resources. |

## Required external inputs (blockers — never invent them)

| Input | Used by | Status |
| --- | --- | --- |
| Azure subscription ID | all Terraform, GitHub variable `AZURE_SUBSCRIPTION_ID` | supplied in local runtime configuration |
| Microsoft Entra tenant ID | AKS Azure RBAC, federated credentials, `AZURE_TENANT_ID` | supplied in local runtime configuration |
| Region | `terraform.tfvars` `location` | supplied in local runtime configuration |
| Globally unique ACR name | `acr_name` in `environments/prod` | supplied in local runtime configuration |
| Resource-group / prefix names | `resource_group_name`, `name_prefix`, `alerting_name_prefix` | supplied in local runtime configuration |
| Bootstrap principal (Storage Blob Data Contributor on state account) | `bootstrap-state` apply | live and verified |
| Entra groups for AKS cluster-admin | `azure_rbac_admin_group_object_ids` | supplied in local runtime configuration |
| Private-network execution host with VNet + private-DNS reach to the AKS API and state/ACR private endpoints | stage-2/3 Terraform applies | jump VM is available and has proven private AKS access; a GitHub self-hosted runner is not required by the current read-only promotion workflow |
| Discord webhook URL (optional) | `TF_VAR_discord_webhook_url` only | not supplied; alerting disabled |

## Phase A — Foundation (LIVE_VALIDATED)

1. `bootstrap-state`: `LIVE_VALIDATED`; shared keys are disabled, the state
   account is private, and the Blob Private Endpoint is approved.
2. Prod remote backend: `LIVE_VALIDATED`; the migrated state is readable from
   the private jump VM and the post-migration core plan had no replacement.
3. Stage 1: `LIVE_VALIDATED`; private FQDN, OIDC issuer, ACR, and identities
   exist in the live resource group.
4. ACR: `LIVE_VALIDATED`; `admin_enabled = false` and
   `anonymous_pull_enabled = false`. Public ACR access remains enabled only so
   hosted GitHub release jobs can reach it before a private runner is supplied.
5. Set GitHub repository variables from the outputs (no secrets):
   `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`,
   `ACR_LOGIN_SERVER`, `ACR_REPOSITORY`, `COSIGN_REPOSITORY`, and later
   any variables explicitly required by a future owner-approved release
   integration.
6. CI federation subject is `LIVE_VALIDATED` as exactly
   `repo:devSatym/gcp-supply-chain-security:ref:refs/heads/main` and that a
   dry-run OIDC exchange from a non-main ref is rejected.

## Phase B — Admission and runtime stages (LIVE_VALIDATED for installed controls)

7. From the private host: `enable_workload_addons = true` is `LIVE_VALIDATED`;
   confirm Kyverno
   admission pod has the `azure.workload.identity/use` label, its
   ServiceAccount carries the rendered client-id annotation, and the rendered
   ClusterPolicy is `Enforce` with the three verify rules. Argo CD was installed
   from the same staged convergence and its server is ClusterIP-only with no
   ingress. The live custom Falco rule is also present; the alerting path stays
   disabled until its owner input is supplied.
8. Optionally `enable_runtime_alerting = true` with `TF_VAR_discord_webhook_url`
   through a temporary, uncommitted tfvars value; confirm the Key Vault secret
   is write-only (absent from state) and the Function holds only Event Hubs
   Data Receiver + Key Vault Secrets User + host-storage roles.
9. Stage 3: `enable_private_endpoints = true`; confirm registry (registry +
   data), Key Vault, Event Hubs, and Function-storage endpoints resolve inside
   the VNet and `registry_public_access_enabled` output is `false`. For the
   Function host storage account, verify private DNS resolution and host
   operation for **all three** services — Blob (`*.blob.core.windows.net`),
   Queue (`*.queue.core.windows.net`), and Table (`*.table.core.windows.net`)
   — and confirm the Function starts and runs using only its managed identity
   before accepting stage-3 closure.

## Phase C — Release trust chain (LIVE_VALIDATION_PENDING)

10. Push to canonical `main` touching `app/**`/`Dockerfile`: `LIVE_VALIDATION_PENDING`;
    confirm the
    azure-deploy chain runs build → Trivy scan → sbom-vex → sign-attest →
    verify → lock → promote, and records the immutable
    `repository@sha256:<digest>` and the `values.release.yaml` artifact.
11. GitOps promotion: add the generated `values.release.yaml` in an
    owner-reviewed change, verify it contains the exact locked digest, and only
    then enable Argo `automated` sync. Confirm the Application targets the
    in-cluster API and the workload becomes Healthy.
12. Do not treat an absent private runner as a deploy failure: the current
    workflow has no imperative Helm deploy job. Any future imperative path must
    be separately approved and retain the narrow Cluster User/RBAC Writer
    scopes.
13. Admission tests (all Azure-only evidence):
    - verified digest is admitted, and `kubectl get deployment` shows the digest;
    - unsigned ACR digest is rejected;
    - mutable tag (`:latest`-style) is `LIVE_VALIDATED` as rejected by the
      server-side dry-run on 2026-08-30;
    - signature from a non-`azure-sign-attest` workflow identity is rejected;
    - provenance with wrong entryPoint/source is rejected;
    - signed main container with unsigned init container is rejected.
14. Confirm a re-push of the locked digest (write-enabled false) fails, while
    `COSIGN_REPOSITORY` metadata writes still succeed.

## Phase D — Runtime security (LIVE_VALIDATION_PENDING)

15. Trigger the approved Falco shell rule in a disposable signed workload;
    confirm the Event Hubs message appears and the Function posts the Discord
    embed using managed identity.
16. Rotate the Discord webhook in Key Vault (increment
    `discord_webhook_secret_version`, re-apply) and confirm delivery without
    committing any secret value.

## Evidence rules

- Record Azure portal/CLI screenshots or command output beside each item in
  `docs/my-validation/` only if clearly named as Azure evidence, or a new
  `docs/azure/evidence/` directory; never rename GCP evidence.
- Record the executed command and result for every live item.

## Cleanup

- Export a cost report for the resource group before destruction.
- Preserve admission/runtime test evidence before deleting disposable images.
- Destroy only the resource group(s) explicitly in scope; keep the Terraform
  state account and its soft-deleted versions unless the owner directs
  otherwise. Do not run destructive commands automatically.
