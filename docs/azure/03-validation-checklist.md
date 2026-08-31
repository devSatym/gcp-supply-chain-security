# Azure validation and evidence checklist

Static checks and live checks are tracked separately. As of 2026-08-30, the
private Azure foundation, one-pass Kyverno/Falco add-ons, admission policy,
Argo foundation, Falco custom-rule wiring, and AKS maintenance parity are
live-validated. Flow-log opt-in, trusted image release, reviewed GitOps
promotion, optional Discord alerting, and private ACR closure remain pending
for the reasons recorded below.
Record command output or new Azure screenshots beside the relevant item; do not
reuse GCP screenshots as Azure evidence.

The 2026-08-30 live entries below are historical evidence from the prior
private jump-host environment. On 2026-08-31, the authenticated subscription
probe found neither the workload resource group nor the state resource group;
therefore no current live deployment is claimed by this revision.

## Static validation

- [x] `terraform fmt -check -recursive infrastructure/azure`
- [x] `terraform init -backend=false` and `terraform validate` in every Azure
  module/root.
- [x] `git diff --check`
- [x] Python source compilation and unit tests for the Function payload path.
- [x] YAML rendering/validation of Azure Kyverno and ACR application manifests.
- [x] Existing policy identity and JMESPath tests still pass.
- [x] Azure policy, Falco parity, and GitOps promotion contract tests pass.
- [x] Pinned Argo CD chart values render successfully with chart version 10.3.3.

### Static validation results

The original static checks ran on 2026-08-29 with Terraform v1.15.8 (linux_amd64) from
temporary copies outside the repository; no backend, cloud, or plan/apply
operation was performed, and no `.terraform/` artifacts remain in the
repository. These remain static results only; the live results are recorded in
the next section.

| Root / directory | Command | Result |
| --- | --- | --- |
| `infrastructure/azure/bootstrap-state` | `terraform init -backend=false -input=false` | PASS (exit 0) |
| `infrastructure/azure/bootstrap-state` | `terraform validate -no-color` | PASS — "Success! The configuration is valid." |
| `infrastructure/azure/network` | `terraform init -backend=false -input=false` | PASS (exit 0) |
| `infrastructure/azure/network` | `terraform validate -no-color` | PASS |
| `infrastructure/azure/aks` | `terraform init -backend=false -input=false` | PASS (exit 0) |
| `infrastructure/azure/aks` | `terraform validate -no-color` | PASS |
| `infrastructure/azure/supply-chain` | `terraform init -backend=false -input=false` | PASS (exit 0) |
| `infrastructure/azure/supply-chain` | `terraform validate -no-color` | PASS |
| `infrastructure/azure/kubernetes-addons` | `terraform init -backend=false -input=false` | PASS (exit 0) |
| `infrastructure/azure/kubernetes-addons` | `terraform validate -no-color` | PASS |
| `infrastructure/azure/falco` | `terraform init -backend=false -input=false` | PASS (exit 0) |
| `infrastructure/azure/falco` | `terraform validate -no-color` | PASS |
| `infrastructure/azure/falco-alerting` | `terraform init -backend=false -input=false` | PASS (exit 0) |
| `infrastructure/azure/falco-alerting` | `terraform validate -no-color` | PASS |
| `infrastructure/azure/environments/prod` (new root, composes all modules) | `terraform init -backend=false -input=false` (whole-tree temp copy) | PASS (exit 0) |
| `infrastructure/azure/environments/prod` (new root, composes all modules) | `terraform validate -no-color` | PASS — "Success! The configuration is valid." |
| `infrastructure/azure/falco-alerting` (post-repair: public-access variable, empty-webhook allowance, 3 new outputs) | re-run `terraform init -backend=false` + `terraform validate` | PASS |
| `infrastructure/azure/network` (post-repair: added `privatelink-data.azurecr.io` default zone) | re-run `terraform init -backend=false` + `terraform validate` | PASS |
| `infrastructure/azure/supply-chain/examples/complete` | `terraform init -backend=false -input=false` (example module source remapped to the temp copy) | PASS (exit 0) |
| `infrastructure/azure/supply-chain/examples/complete` | `terraform validate -no-color` | PASS |
| whole tree | `terraform fmt -check -recursive infrastructure/azure` | PASS (exit 0) |
| whole tree | `git diff --check` | PASS (exit 0) |
| `functions/discord-notifier/` | `python3 -m py_compile function_app.py test_function_app.py` | PASS |
| `functions/discord-notifier/` | `python3 test_function_app.py` (6 tests: valid event, priority filter, unknown priority, malformed payload, missing Key Vault config, single Key Vault read; webhook never logged) | PASS — 6/6 OK |
| Azure policy + fixtures | `python3 policy/azure/tests/check_azure_policy_contract.py` (renders the ClusterPolicy/values templates, asserts the three rules, Azure-only helper, digest-only flags, attestor pinning, provenance JMESPath contract, fixture coverage, invalid-trust negative contract, identity consistency, no GCP leakage) | PASS |
| Azure Falco parity | `python3 policy/azure/tests/check_falco_contract.py` | PASS |
| Azure GitOps contract | `python3 policy/azure/tests/check_azure_gitops_contract.py` | PASS |
| Argo CD chart values | `helm template argocd argo/argo-cd --version 10.3.3 --namespace argocd --values infrastructure/azure/kubernetes-addons/argocd-values.yaml` | PASS — 44 manifests rendered |
| Azure Helm chart | `helm lint k8s/azure/supply-chain-demo` | PASS — 0 charts failed |
| Azure Helm chart | `helm template` base + `values.release.yaml.example` and offline render assertion | PASS — base is inert; release example renders Deployment/Service with digest-shaped image |
| Azure workflows | YAML parse of `azure-static-validation.yml` after repair (see below) | PASS |
| GCP policy tests | `python3 policy/tests/test_jmespath_conditions.py` | PASS — all Rule 3 conditions match the real provenance predicate shape |
| GCP policy tests | `bash policy/tests/check-identity-consistency.sh` | PASS — all certificate identity references consistent |

### Repair recorded during static validation

- `azure-static-validation.yml` originally ran `kubectl apply --dry-run=client`
  after `helm template`. kubectl v1.34.1 requires live API discovery for that
  command even with `--validate=false`, which cluster-less CI runners cannot
  provide (no GCP workflow uses kubectl, so no precedent existed). The step was
  replaced with an offline render assertion (helm template output parsed with
  PyYAML, Deployment/Service kinds and digest-pinned image verified). The
  replacement was executed locally with the exact CI command logic and passes.
- `kubectl apply --dry-run=client` was therefore recorded as NOT executable
  offline; the covering checks are the helm render assertion above and the
  Azure policy contract script.

### Promotion/deployment additions (static validation only)

- `scripts/azure/apply-once.sh` is the idempotent operator entry point. It
  initializes only the owner-supplied remote Blob backend, copies configuration
  into a disposable temporary tree, applies only saved plans, probes the private
  AKS API, and separates endpoint creation from public-service closure.
- `argocd/supply-chain-azure-demo-app.yaml` now tolerates an absent release file
  and enables prune/self-heal. The base chart is inert until promotion supplies
  `values.release.yaml`; no placeholder image can be scheduled.
- The main-only `promote` job renders the release template only after verify and
  lock, requires exactly `sha256:<64 hex>`, stages only
  `k8s/azure/supply-chain-demo/values.release.yaml`, and is the sole job with
  `contents: write`. It has no Azure or OIDC authority, and narrow chart path
  filters prevent its commit from recursively starting another image release.
- Function VNet integration is wired through the delegated Functions subnet;
  private closure probes Blob, Queue, Table, Key Vault, Event Hubs, and ACR
  endpoints before public service access is disabled.

### Current local validation — 2026-08-31

The following checks were run from the current worktree; Terraform was
initialized and validated only in a temporary copy outside the repository:

- `bash -n scripts/azure/apply-once.sh` — PASS.
- `scripts/azure/apply-once.sh --help` and both dry-run modes — PASS.
- Every Azure Terraform root, including the composed production root,
  `terraform init -backend=false` plus `terraform validate` — PASS.
- `helm lint` for the workload, policy, and Argo Application charts — PASS.
- Azure GitOps and one-command automation contract tests — PASS.
- Base/release Helm render assertion — PASS.

These are static results only. Remote-backend initialization from this host
failed because the configured private Blob hostname was not resolvable; the
live subscription also currently reports the resource groups as absent.

## Live core validation — 2026-08-30

- [x] Remote Terraform state is readable from the private jump VM through the
  approved Blob Private Endpoint; shared-key access remains disabled and state
  public access remains disabled.
- [x] AKS is `Succeeded`, private, and reachable only from the private host;
  the current one-node `Standard_D2s_v7` pool is healthy because of the live
  four-vCPU quota.
- [x] One saved Terraform plan applied the core add-ons: four resources added,
  zero changed, zero destroyed.
- [x] Kyverno and its four controllers are Ready; the dependent Helm-installed
  ClusterPolicy is `Enforce` with the three Azure trust rules.
- [x] Kyverno admission pods carry the workload-identity label and the
  admission ServiceAccount carries the rendered managed-identity client ID.
- [x] Falco daemonset and metadata collector are Ready using the modern eBPF
  driver; Falcosidekick is intentionally disabled while alerting is off.
- [ ] No Azure image has been released yet: the remote `main` branch does not
  contain the local Azure workflow candidate and the ACR has no release image.
- [x] Argo CD foundation is installed with a pinned chart, ClusterIP-only
  services, and no ingress; automatic application sync remains disabled until
  a reviewed digest values file exists.
- [x] AKS exposes both daily maintenance schedules at 03:00 UTC and uses the
  `NodeImage` node OS upgrade channel.
- [x] Mutable-tag admission rejection was live-tested with a server-side
  dry-run from the private jump VM; the remaining admission cases require a
  released image or additional disposable fixtures.
- [ ] Demo deployment, remaining negative admission tests, Discord alerting,
  and ACR private closure remain pending.

## Identity and registry

- [ ] Confirm GitHub CI logs in through OIDC with no client secret.
- [ ] Confirm ACR admin and anonymous pull are disabled.
- [ ] Confirm CI can write only its intended repository paths.
- [ ] Confirm AKS kubelet and Kyverno can read required application/Cosign
  metadata paths, but cannot write them.
- [ ] Push a commit-SHA image, scan it, sign it, attest SPDX/SLSA, and verify
  all three against the expected GitHub workflow identity.
- [ ] Lock the verified release tag/manifest and confirm it cannot be rewritten
  or deleted by the normal CI identity.

## AKS and admission

- [x] Confirm AKS is private, Entra/Azure RBAC-enabled, OIDC/workload identity
  enabled, and nodes are healthy.
- [x] Confirm Kyverno admission-controller pod has the workload-identity label
  and ServiceAccount annotation.
- [x] Confirm the ClusterPolicy is `Enforce` with all three Azure trust rules,
  and Argo CD is installed with ClusterIP-only services and no ingress.
- [ ] Deploy the signed ACR image by digest and confirm admission/Argo health.
- [ ] Confirm an unsigned ACR image is rejected.
- [ ] Confirm a signed-main/unsigned-init-container manifest is rejected.
- [ ] Confirm invalid signing workflow/provenance identity is rejected.

## Runtime alerts

- [ ] Confirm Falcosidekick has the workload-identity label/annotation and an
  Event Hubs Data Sender role only.
- [ ] Trigger the approved Falco shell rule in a disposable signed workload.
- [ ] Confirm an Event Hubs event appears and the Function processes it using
  managed identity.
- [ ] Confirm the Discord webhook is read from Key Vault and alert delivery
  succeeds. Rotate it and repeat without committing a secret.

## Cleanup

- [ ] Record resource cost/export before destructive cleanup.
- [ ] Delete disposable negative-test images only after preserving evidence.
- [ ] Destroy only the Azure resource group(s) explicitly in scope; retain or
  intentionally archive state according to the owner’s retention policy.
