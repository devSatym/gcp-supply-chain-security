# Azure live recovery and state repair

## Goal

Recover the existing Azure deployment by making Terraform state durable and reachable from the private AKS network, then continue the staged add-on and private-closure rollout without weakening OIDC, private AKS, digest-only deployment, or secret-handling invariants. The live review found that the VM identity can reach private AKS but storage access is denied by network rules, while the prod root is still using local state because it has no AzureRM backend declaration; exact source and live scope are listed below.

## Exact file scope

This plan may touch only the paths explicitly listed under each task. The existing GCP implementation, unrelated tracked edits, generated plans/state, provider caches, binaries, and live Azure resources are out of scope unless a task explicitly identifies them as live-only validation targets.

## Current evidence to preserve

- Live subscription/tenant/region and resource names are owner-supplied runtime values; do not hardcode them into source or this plan.
- The jump VM identity token has the expected object ID and Storage audience, and the same identity successfully obtained AKS credentials and ran `kubectl get nodes` against the private API.
- The state account is `publicNetworkAccess = Enabled`, `defaultAction = Deny`, `allowSharedKeyAccess = false`, has no private endpoints, and only lists the operator and NAT public addresses as IP rules.
- The jump VM is in the same East US region and subnet as the NAT gateway but also has an instance public IP. Azure documents that same-region Azure service traffic may use private service paths, and recommends Private Link for private storage access; do not treat the NAT IP allowlist as proof of storage reachability.
- The `tfstate` container currently has no blob, while local prod state has serial 61 and contains the stage-1 resources. Do not destroy or overwrite that local state until remote migration is verified.
- Generated `terraform.tfstate`, `.terraform/`, and `*.tfplan` artifacts are present in the dirty candidate worktree. They are not importable implementation and must not be committed or copied into a clean implementation worktree.

## Tasks

### 1. Declare and document the AzureRM remote backend

File scope (edit only):

- `infrastructure/azure/environments/prod/versions.tf`
- `infrastructure/azure/environments/prod/README.md`
- `docs/azure/02-setup.md`
- `docs/azure/04-live-validation-checklist.md`

Steps:

1. Add an empty `backend "azurerm" {}` block to the prod root. Keep all account, resource-group, container, key, subscription, tenant, and runner values supplied through `terraform init -backend-config` or environment variables; do not put live values in source.
2. Keep Azure AD/OIDC backend authentication enabled in the documented backend configuration. Do not add access keys, SAS tokens, client secrets, or kubeconfig material.
3. Correct the setup sequence to distinguish the one-time local bootstrap root from the prod root. State migration must happen only after the private or explicitly allowlisted backend path is tested, and the local state must remain recoverable until the remote blob is confirmed.
4. Record that the current live prod state is local-only and that the empty `tfstate` container is a migration blocker, not evidence that stage 1 was never applied.
5. Keep stage gates unchanged: this task must not enable add-ons, runtime alerting, private endpoints, or public AKS access.

Validation commands:

```bash
terraform fmt -check infrastructure/azure/environments/prod
terraform -chdir=infrastructure/azure/environments/prod init -backend=false -input=false
terraform -chdir=infrastructure/azure/environments/prod validate -no-color
git diff --check
```

Abort/rollback condition: stop if Terraform requires backend values in source, if validation tries to contact Azure, if any secret or generated state enters a tracked file, or if the edit changes a stage gate or provider authentication mode. Leave the existing local state untouched.

### 2. Add an explicit Private Link path for bootstrap state

Status: `BLOCKED_BY_EXTERNAL_INPUT` for live application; static implementation may proceed only in a clean implementation worktree after Task 1.

File scope (edit only):

- `infrastructure/azure/bootstrap-state/main.tf`
- `infrastructure/azure/bootstrap-state/variables.tf`
- `infrastructure/azure/bootstrap-state/outputs.tf`
- `infrastructure/azure/bootstrap-state/README.md`

Steps:

1. Add an opt-in state Blob private endpoint resource using the existing bootstrap storage account, an owner-supplied private-endpoint subnet ID, and an owner-supplied `privatelink.blob.core.windows.net` DNS zone ID. The endpoint must use the `blob` subresource and a private DNS zone group.
2. Add variable validation so enabling the endpoint requires both IDs; keep the default disabled for the initial one-time bootstrap because the workload VNet is created by a separate root.
3. Export the endpoint ID and the account/blob host information needed for live DNS and connectivity checks. Outputs must contain identifiers only, never tokens, keys, webhook values, or state contents.
4. Document the safe sequence: create workload network/DNS first; apply the bootstrap root locally to create the endpoint while public access remains available; verify private access from the VNet; then re-apply bootstrap state with `public_network_access_enabled = false`. Do not disable public access in the same unverified step that creates the endpoint.
5. Explain that the VM managed identity must be included in `state_operator_principal_ids` so the Storage Blob Data Contributor assignment is Terraform-owned. Do not preserve an out-of-band role assignment as the source of truth.

Validation commands:

```bash
terraform fmt -check infrastructure/azure/bootstrap-state
terraform -chdir=infrastructure/azure/bootstrap-state init -backend=false -input=false
terraform -chdir=infrastructure/azure/bootstrap-state validate -no-color
git diff --check
```

Abort/rollback condition: stop if the endpoint requires a guessed subnet/zone/name, if the design introduces a storage key/SAS or broad `AzureServices` bypass, if the bootstrap root acquires a remote backend dependency on the workload root, or if provider validation fails. Do not disable the live storage public endpoint until private DNS and Blob authorization are proven from the VNet.

### 3. Migrate the existing stage-1 state and repair VM Blob access

Status: `BLOCKED_BY_EXTERNAL_INPUT` — requires authorized Azure mutation, the owner-approved subnet/DNS IDs, and the operator’s protected local state backup.

File scope: no repository files; live Azure resources and ignored local Terraform state only.

Steps:

1. Preserve a protected, out-of-repository backup of the current local prod state and record its serial/lineage without printing state contents. Do not use `git clean`, `git reset`, `git stash`, or broad deletion.
2. Add the VM identity object ID to the bootstrap root’s owner-supplied `state_operator_principal_ids` input and apply the bootstrap private-endpoint change from the local bootstrap root. Keep the account key-disabled and OAuth-only settings.
3. From the jump VM, verify that the storage Blob hostname resolves to the private endpoint and that `az storage blob list --auth-mode login` succeeds with the VM managed identity. Use a bounded read-only test; do not fall back to a key, SAS, or connection string.
4. From the operator host, initialize the now-backend-enabled prod root with the owner-supplied backend configuration and run `terraform init -migrate-state -input=false`. Confirm the state blob exists in `tfstate` and that a subsequent `terraform state list` reads the same stage-1 addresses.
5. From the jump VM, run a second backend read test using the managed identity. Only after both tests pass may the bootstrap account be switched to `public_network_access_enabled = false` and the temporary public IP rules be retired.
6. Re-run a no-change `terraform plan` against the migrated remote state before any add-on apply. If the plan proposes replacement of existing stage-1 resources, stop and reconcile state; do not approve a destructive apply.

Validation commands (live, and therefore blocked until the required inputs are authorized):

```bash
az storage blob list --account-name <owner-state-account> --container-name tfstate --auth-mode login --query '[].{name:name,size:properties.contentLength}' -o table
az vm run-command invoke --resource-group <owner-vm-rg> --name <owner-vm> --command-id RunShellScript --scripts 'getent hosts <owner-state-account>.blob.core.windows.net; az login --identity >/dev/null; az storage blob list --account-name <owner-state-account> --container-name tfstate --auth-mode login --query "[].name" -o tsv'
terraform -chdir=infrastructure/azure/environments/prod init -migrate-state -input=false -backend-config=<owner-backend-config>
terraform -chdir=infrastructure/azure/environments/prod state list
terraform -chdir=infrastructure/azure/environments/prod plan -input=false -out=<protected-temp-dir>/post-migration.tfplan
```

Abort/rollback condition: stop before disabling public access if private DNS does not resolve, Blob list/download is not authorized, the state blob is absent, backend migration changes lineage unexpectedly, or the no-change plan proposes replacement. Keep the local state and public access needed for the last known-good operator path; never delete the local state or remote versions during recovery.

### 4. Continue the staged add-on deployment from the private host

Status: `BLOCKED_BY_EXTERNAL_INPUT` — depends on Task 3 and the owner-authorized private-network runner/VM.

File scope: no repository files; live Terraform/Kubernetes resources only.

Steps:

1. On the private host, use the migrated AzureRM backend and the existing owner-supplied prod inputs. Keep the deployment at one node only for the quota workaround until the add-ons are healthy.
2. Set only `enable_workload_addons = true`; keep `enable_private_endpoints = false` until stage-2 DNS and provider access are proven, and keep Discord disabled unless the owner supplies `TF_VAR_discord_webhook_url` through the write-only Key Vault path.
3. Run a saved Terraform plan, inspect it for unexpected stage-1 changes, then apply that exact plan. Do not apply an unreviewed plan and do not create a public AKS endpoint.
4. Verify private API access, Kyverno workload identity label/annotation, ClusterPolicy `Enforce` state, signed-digest admission behavior, Falco daemonset health, and Event Hubs identity wiring if alerting was explicitly enabled.

Validation commands (live and blocked until Task 3 succeeds):

```bash
terraform -chdir=infrastructure/azure/environments/prod plan -input=false -out=<protected-temp-dir>/stage2.tfplan
terraform -chdir=infrastructure/azure/environments/prod apply <protected-temp-dir>/stage2.tfplan
kubectl get nodes -o wide
kubectl -n kyverno get pods -o wide
kubectl get clusterpolicy -o wide
kubectl -n falco-system get daemonset,pods -o wide
kubectl -n default get deployment supply-chain-demo -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

Abort/rollback condition: stop if the private API, backend, ACR, or private DNS path is unavailable; if any image is tag-only; if Kyverno is not enforcing; if a provider plan wants to replace stage-1 infrastructure; or if a secret appears in plan output/logs. Do not disable policy enforcement to make an add-on apply pass.

### 5. Close private networking, harden operator access, and record evidence

Status: `BLOCKED_BY_EXTERNAL_INPUT` — requires owner approval of the private runner/Bastion/VPN path and live validation of all private endpoints.

File scope (edit only after the live changes succeed):

- `docs/azure/01-gap-assessment.md`
- `docs/azure/03-validation-checklist.md`
- `docs/azure/04-live-validation-checklist.md`
- `infrastructure/azure/environments/prod/README.md`

Steps:

1. Enable the existing prod private-endpoint gate only after the private runner can resolve and reach ACR registry/data, Key Vault, Event Hubs, Function storage Blob/Queue/Table, and the bootstrap state Blob endpoint.
2. Verify `public_network_access_enabled = false` for the workload data services and bootstrap state account, and verify private DNS from the private host. Keep all storage keys, connection strings, and public AKS fallbacks disabled.
3. Remove the jump VM’s instance public IP or replace ad-hoc SSH with an owner-approved Azure Bastion, VPN, or private GitHub runner path. Never widen SSH to `0.0.0.0/0`; the current public VM IP and stale CGNAT allowlist are an operational and exposure concern.
4. Restore the intended node-pool sizes only after add-ons and admission tests pass, then verify cluster health and cost posture.
5. Update the Azure documents to distinguish `LIVE_VALIDATED`, `LIVE_VALIDATION_PENDING`, and `BLOCKED_BY_EXTERNAL_INPUT`, recording only redacted command results and Azure evidence. Explicitly record that GCP evidence remains GCP-only.
6. In the clean implementation worktree, ensure Terraform plans/state/caches are ignored and absent from the candidate import. Do not modify or delete the dirty worktree’s user-owned artifacts during this review.

Validation commands:

```bash
terraform fmt -check infrastructure/azure/environments/prod
git diff --check
python3 - <<'PY'
from pathlib import Path
for path in [Path('docs/azure/01-gap-assessment.md'), Path('docs/azure/03-validation-checklist.md'), Path('docs/azure/04-live-validation-checklist.md')]:
    text = path.read_text()
    assert 'LIVE_VALIDATED' in text
PY
```

Live validation remains blocked until the owner approves the private access method, runner labels, and any optional alerting webhook. Abort/rollback condition: stop if private endpoint DNS or Function host storage health fails, if the public AKS endpoint is enabled, if state is not recoverable, or if evidence would expose credentials, tokens, webhook values, or unredacted state.

Ready for implementation one task at a time.
