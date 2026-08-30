# Azure validation and evidence checklist

Static checks and live checks are tracked separately. As of 2026-08-30, the
private Azure foundation, one-pass Kyverno/Falco add-ons, admission policy,
Argo foundation, Falco custom-rule wiring, and AKS maintenance parity are
live-validated. Flow-log opt-in, trusted image release, reviewed GitOps
promotion, optional Discord alerting, and private ACR closure remain pending
for the reasons recorded below.
Record command output or new Azure screenshots beside the relevant item; do not
reuse GCP screenshots as Azure evidence.

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
| Azure Helm chart | `helm template supply-chain-demo k8s/azure/supply-chain-demo` + offline render assertion (Deployment/Service kinds present, deployment image digest-pinned) | PASS — 2 documents rendered |
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

- Repair Task 3 (Codex review follow-up): Function host storage private
  connectivity completed. `infrastructure/azure/network/variables.tf` added
  `privatelink.queue.core.windows.net` and `privatelink.table.core.windows.net`
  defaults; the prod root gained `function_storage_queue` and
  `function_storage_table` private endpoints (`queue`/`table` subresources,
  each attached to its zone), all Function-storage endpoints gated on
  `enable_private_endpoints && enable_runtime_alerting`. The Function host uses
  identity-based `AzureWebJobsStorage` requiring exactly Blob, Queue, and
  Table (no Files subresource — no `WEBSITE_CONTENTAZUREFILECONNECTIONSTRING`,
  zip deployment). Validation: fmt -check on both directories PASS;
  `terraform init -backend=false` + `validate` for network and prod roots in a
  temp copy PASS; offline assertion for the two zones and two endpoints PASS;
  `git diff --check` PASS.

- Repair Task 1 (Codex review follow-up): `syncPolicy.automated` (prune/selfHeal)
  removed from `argocd/supply-chain-azure-demo-app.yaml`. Validation:
  offline YAML assertion confirms `"automated" not in syncPolicy` (PASS),
  `helm lint k8s/azure/supply-chain-demo` (PASS), `helm template` render
  (PASS), `git diff --check` (PASS). Rationale recorded in the app manifest
  comment and `docs/azure/02-implementation-backlog.md` (B3): private-runner
  Helm is the release manager; Argo automatic sync stays disabled while
  committed values are placeholders, and may be restored only through an
  owner-approved promotion-commit mechanism that writes only the verified and
  locked digest.

- `azure-deploy.yml` promotion is main-only with `contents: read`; it renders
  the verified digest into `values.release.yaml` plus a full manifest evidence
  artifact. Direct Helm deployment was removed so the reviewed Argo CD
  Application remains the sole GitOps release boundary.
- The exact promote render logic was executed locally with placeholder values
  and a well-formed digest: `envsubst` render + `helm template` +
  digest-grep on the rendered manifest = PASS. The initial grep against the
  values file (before the fix) correctly failed locally — repository and
  digest render on separate lines in values.yaml, so the digest assertion must
  run against the rendered manifest; the workflow encodes the corrected order.
- `docs/azure/04-live-validation-checklist.md` remains the live execution gate.
  Trusted image release, reviewed values promotion, and private closure remain
  `LIVE_VALIDATION_PENDING`.

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
