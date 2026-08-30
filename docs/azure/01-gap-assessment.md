# 01 — Detailed gap assessment (Task 0.2)

Component-by-component review of the Azure implementation. Every
classification below is based on reading actual file content and the current
offline validation results.

Classification values:

- `IMPLEMENTED_AND_VALIDATED` — implemented and backed by recorded validation evidence.
- `IMPLEMENTED_BUT_UNVERIFIED` — implemented and coherent on review, but no validation evidence yet.
- `PARTIAL` — some of the required behavior exists; a real boundary is missing.
- `INCORRECT` — contradicts the security contract or cannot work as written.
- `MISSING` — required component absent.
- `BLOCKED_BY_EXTERNAL_INPUT` — cannot proceed without subscription/tenant/runner/webhook inputs.

Static-validation evidence current on 2026-08-30: all Azure Terraform roots
pass `terraform init -backend=false` and `terraform validate` from clean
temporary copies outside the repository, and
`terraform fmt -check -recursive infrastructure/azure` passes. The
workload add-on, policy, Falco, GitOps, workflow-YAML, and pinned Argo-chart
offline contracts also pass. The private jump VM live-validated the private
AKS foundation, Kyverno/Falco controls, Argo CD foundation, storage access, and
AKS maintenance parity on 2026-08-30; live release promotion and private
closure remain external-input dependent. See
`docs/azure/evidence/2026-08-30-live-core.md` for Azure-only proof.

## Terraform

| Component | Files | Classification | Finding |
| --- | --- | --- | --- |
| State/bootstrap | `infrastructure/azure/bootstrap-state/` | IMPLEMENTED_BUT_UNVERIFIED | Storage keys disabled (`shared_access_key_enabled = false`, `storage_use_azuread = true`), deny-by-default firewall with precondition, versioning + soft delete, private container, operator role assignments. Backend config output uses `use_azuread_auth`/`use_oidc`. Passed init+validate (temp copy). |
| Networking | `infrastructure/azure/network/` | IMPLEMENTED_BUT_UNVERIFIED | VNet, non-delegated AKS-node subnet, delegated API-server subnet (AKS API Server VNet Integration), private-endpoint subnet, Functions delegation subnet, NAT-gateway-controlled egress, private DNS zones for ACR/Blob/Service Bus/Vault, explicit deny-SSH/RDP rules, opt-in VNet flow logs. No public exposure introduced. |
| Private AKS | `infrastructure/azure/aks/` | IMPLEMENTED_AND_VALIDATED | `private_cluster_enabled = true`, `local_account_disabled = true`, Azure RBAC with Entra groups, OIDC + workload identity enabled, API-server VNet integration, CNI overlay + `azure` network policy, `userAssignedNATGateway` outbound, Container Insights with MSI. Kubelet ACR pull is optional and roles scoped. No public API fallback. The live cluster is private, Ready, and exposes both daily maintenance schedules. |
| ACR | `infrastructure/azure/supply-chain/main.tf` (registry) | IMPLEMENTED_BUT_UNVERIFIED | Premium SKU, `admin_enabled = false`, `anonymous_pull_enabled = false`, `role_assignment_mode = "AbacRepositoryPermissions"`, retention policy, `network_rule_bypass_option = "None"`. Precondition keeps application and Cosign metadata repositories separate. |
| Identities | `infrastructure/azure/supply-chain/main.tf` (identities) | IMPLEMENTED_BUT_UNVERIFIED | Separate UAMIs: GitHub CI (repository writer only), Kyverno verifier (repository reader only), AKS kubelet reader roles optional via principal input. Catalog-lister roles are opt-in and default-disabled. ABAC conditions scope grants to the two repository paths. |
| GitHub federation | `azurerm_federated_identity_credential.github_ci_main` | IMPLEMENTED_BUT_UNVERIFIED | Subject is exactly `repo:devSatym/gcp-supply-chain-security:ref:refs/heads/main` (variable validation pins the repository); audience `api://AzureADTokenExchange`. PRs/branches cannot exchange tokens for this identity. |
| Workload federation (Kyverno) | `azurerm_federated_identity_credential.kyverno` | IMPLEMENTED_BUT_UNVERIFIED | Uses AKS OIDC issuer with exact `system:serviceaccount:<ns>:<sa>` subject. |
| Supply-chain composition | `infrastructure/azure/environments/prod/` | IMPLEMENTED_BUT_UNVERIFIED | The production root composes network → private AKS → supply-chain → add-ons/Falco/optional alerting, and gates private endpoints behind `enable_private_endpoints`. The root is statically validated; live stage transitions remain pending. |
| Private endpoints (ACR/Key Vault/Event Hubs/Storage) | `infrastructure/azure/environments/prod/main.tf` | IMPLEMENTED_BUT_UNVERIFIED | The root creates ACR registry/data endpoints and, when alerting is enabled, Key Vault, Event Hubs, and Function Storage Blob/Queue/Table endpoints, then flips child public access flags off. Requires a private DNS/runner live proof before enabling. |
| Image locking (Terraform side) | — | PARTIAL | Deliberately absent from Terraform. Locking is workflow/CLI-based (`azure-lock-image.yml`, `az acr repository update`). Docs correctly state ACR has no Terraform immutable-tag switch. Requires live verification that the CI identity's ABAC writer condition permits repository-attribute updates on the digest (AGENT.md item 1.5). |
| Kyverno add-ons | `infrastructure/azure/kubernetes-addons/` | IMPLEMENTED_BUT_UNVERIFIED | Installs pinned Kyverno chart (3.9.0) with Azure values template, then applies the rendered ClusterPolicy via `kubernetes_manifest` with a documented two-phase-apply CRD caveat. Renders `policy/azure/kyverno/*` through `templatefile` (cross-tree dependency, resolved relative to repo root). |
| Falco | `infrastructure/azure/falco/` | IMPLEMENTED_BUT_UNVERIFIED | `modern_ebpf` driver default (no kernel-module builds), Kubernetes collector, tolerations, pinned chart 9.1.0, and the GCP active CRITICAL shell-spawn rule ported to the Azure root. Falcosidekick config supplies `workloadIdentityClientID`; Event Hubs output uses namespace FQDN + hub name — no connection strings. |
| Event Hubs | `infrastructure/azure/falco-alerting/main.tf` (EH) | IMPLEMENTED_BUT_UNVERIFIED | `local_authentication_enabled = false` (no SAS keys). Namespace `public_network_access_enabled = true` — acceptable bootstrap posture, but private-endpoint closure is part of the missing private-mode work above. |
| Alerting / Key Vault | `infrastructure/azure/falco-alerting/main.tf` (KV) | IMPLEMENTED_BUT_UNVERIFIED | Key Vault RBAC-only, purge protection, soft delete; Discord webhook stored via write-only `value_wo` + version counter (state never contains the webhook); Function gets `Key Vault Secrets User` only. |
| Functions | `infrastructure/azure/falco-alerting/main.tf` (Function) + `functions/discord-notifier/` | IMPLEMENTED_BUT_UNVERIFIED | Linux Python 3.12 Function with system-assigned identity; `storage_uses_managed_identity`, identity-based `AzureWebJobsStorage__*` and `EventHubConnection__*` settings; Event Hubs Data Receiver; zip deploy from `archive_file` (output under `.build/`, git-ignored by `falco-alerting/.gitignore`). Role breadth (Blob Data Owner + Queue Data Contributor + Storage Account Contributor) is a Task 4.2 least-privilege review item, not a defect. |

## Kubernetes

| Component | Files | Classification | Finding |
| --- | --- | --- | --- |
| Workload chart | `k8s/azure/supply-chain-demo/` | IMPLEMENTED_BUT_UNVERIFIED | Digest-only image (`repository@digest`), `runAsNonRoot` 10001, seccomp RuntimeDefault, read-only root FS, ALL capabilities dropped, resource requests/limits, probes. No pull secrets, no GCR/GAR references. |
| Namespace | `argocd/supply-chain-azure-demo-app.yaml` (`destination.namespace: default`) | IMPLEMENTED_BUT_UNVERIFIED | App deploys into `default` (same pattern as the GCP app). Acceptable; confirm against Kyverno exclusion list (only system namespaces excluded) — the demo namespace is not excluded, which is correct for enforcement. |
| Helm values / image references | `k8s/azure/supply-chain-demo/` | IMPLEMENTED_BUT_UNVERIFIED | Base values remain inert placeholders, `values.release.yaml.example` documents the reviewed override shape, and the main-only promotion job emits a concrete digest-pinned `values.release.yaml` artifact. |

## GitOps

| Component | Files | Classification | Finding |
| --- | --- | --- | --- |
| Argo CD Application | `argocd/supply-chain-azure-demo-app.yaml` + `kubernetes-addons` | IMPLEMENTED_BUT_UNVERIFIED | Pinned private Argo CD chart installation is wired into the workload add-ons, and the Application tracks `main` with `values.release.yaml`. Automatic sync remains disabled until that reviewed file exists. |
| Digest propagation | `azure-deploy.yml` `promote` job | PARTIAL | Main-only `promote` renders the verified/locked digest into an artifact with `contents: read`. Committing that artifact as `values.release.yaml` and re-enabling Argo automation is an owner-reviewed release action, not an automatic repository mutation. |

## Supply-chain security

| Component | Files | Classification | Finding |
| --- | --- | --- | --- |
| Signing | `.github/workflows/azure-sign-attest.yml` | IMPLEMENTED_BUT_UNVERIFIED | Keyless Cosign sign of `...@sha256:<digest>`; metadata routed to the separate mutable `COSIGN_REPOSITORY`; `TRUSTED_REF` pinned to `refs/heads/main`; entryPoint derived from the signed OIDC token's `job_workflow_ref` and asserted equal to `azure-sign-attest.yml`. |
| SBOM | same workflow | IMPLEMENTED_BUT_UNVERIFIED | Syft SPDX JSON attested as `spdxjson`; artifact uploaded. |
| SLSA provenance | same workflow | IMPLEMENTED_BUT_UNVERIFIED | SLSA v0.2 predicate with builder id, configSource URI pinned to `@refs/heads/main`, materials commit, and verified entryPoint. |
| Independent verification | `.github/workflows/azure-verify.yml` | IMPLEMENTED_BUT_UNVERIFIED | Strict `cosign verify`/`verify-attestation` with jq contracts: exact digest match, signer identity = `azure-sign-attest.yml@refs/heads/main`, SPDX subject digest, provenance builder/entryPoint/source/commit/materials. Fails closed (`if length == 0 then error(...)`). |
| Image locking | `.github/workflows/azure-lock-image.yml` | PARTIAL | `az acr repository update --image <repo>@<digest> --write-enabled false --delete-enabled false` after verify. Plausible per ACR image-lock docs, but unverified against the ABAC role conditions and the CLI's digest-level locking behavior; metadata repository stays mutable by design. |
| Build/scan | `.github/workflows/azure-build-push.yml` | IMPLEMENTED_BUT_UNVERIFIED | SHA-tag build, digest output, Trivy CRITICAL/HIGH gate by digest, SARIF upload. |

## Admission security

| Component | Files | Classification | Finding |
| --- | --- | --- | --- |
| Kyverno policy | `policy/azure/kyverno/block-unsigned-images.yaml` | IMPLEMENTED_BUT_UNVERIFIED | Three rules (signature, SPDX, SLSA provenance) in `Enforce` with `background: true`; `imageRegistryCredentials.helpers: [azure]`; `repository` points at the metadata repo; `verifyDigest: true`, `mutateDigest: false`, `required: true`; keyless attestor pinned to `azure-sign-attest.yml@refs/heads/main` + GitHub issuer + Rekor; provenance conditions pin entryPoint, builder, and source URI. Unrendered template cannot match real images (safe-by-default). |
| Digest-only enforcement | policy + chart | IMPLEMENTED_BUT_UNVERIFIED | `verifyDigest`/`mutateDigest: false` plus digest-pinned chart deployment. |
| Kyverno workload identity | `policy/azure/kyverno/values.yaml` | IMPLEMENTED_BUT_UNVERIFIED | `azure.workload.identity/use: "true"` pod label and `client-id` SA annotation rendered from the Terraform output; `credentialHelpers: [azure]`, `allowInsecure: false`. |
| Init-container coverage | policy + `test-init-unsigned.yaml` | IMPLEMENTED_BUT_UNVERIFIED | `verifyImages` applies to init/ephemeral containers by default; the Azure fixture and policy contract now prove that an unsigned init cannot bypass the signed main container. |
| Trust-contract static test | `policy/azure/tests/` + `azure-static-validation.yml` | IMPLEMENTED_BUT_UNVERIFIED | Checks the exact three rules, Azure-only helper, placeholder-safe references, no GCP registry leakage, provenance condition set, invalid-trust negative contract, Falco parity, GitOps promotion, and chart contract. |

## Runtime security

| Component | Files | Classification | Finding |
| --- | --- | --- | --- |
| Falco/Falcosidekick | `infrastructure/azure/falco/` | IMPLEMENTED_BUT_UNVERIFIED | See Terraform table. |
| Falcosidekick identity | `falco-alerting` federation subject default `system:serviceaccount:falco-system:falco-falcosidekick` | IMPLEMENTED_BUT_UNVERIFIED | Must match the chart-generated ServiceAccount name for release 9.1.0 (`falco-falcosidekick`); verify during Helm render/plan. |
| Event Hubs delivery | `falco-alerting` + `falco` | IMPLEMENTED_BUT_UNVERIFIED | Data Sender role only for Falcosidekick; Data Receiver only for the Function; no SAS keys anywhere (`local_authentication_enabled = false`). |

## Azure Functions relay

| Component | Files | Classification | Finding |
| --- | --- | --- | --- |
| Relay logic | `functions/discord-notifier/function_app.py` | IMPLEMENTED_BUT_UNVERIFIED | Event Hub trigger (cardinality one), priority filter (unknown priorities forwarded), webhook fetched at runtime from Key Vault via `DefaultAzureCredential`, posts Discord embed, logs never include the webhook. Malformed payloads are dropped with a warning. |
| Unit tests | `functions/discord-notifier/test_function_app.py` | IMPLEMENTED_BUT_UNVERIFIED | Six local tests cover valid events, priority behavior, malformed payloads, missing Key Vault configuration, and the no-webhook-logging contract. |

## CI/CD

| Component | Files | Classification | Finding |
| --- | --- | --- | --- |
| Azure auth action | `.github/actions/azure-auth/action.yml` | IMPLEMENTED_BUT_UNVERIFIED | OIDC-only `azure/login` (SHA-pinned), `az acr login --expose-token` with `add-mask`, zero-GUID Docker username, no client secrets. |
| Static validation workflow | `.github/workflows/azure-static-validation.yml` | IMPLEMENTED_BUT_UNVERIFIED | PR/push/dispatch; `permissions: contents: read` only — no `id-token`, no Azure login; YAML parse + policy/Falco/GitOps contract assertions + Helm render + per-root fmt/init/validate. |
| Orchestrator | `.github/workflows/azure-deploy.yml` | IMPLEMENTED_BUT_UNVERIFIED | Main path: build-push → SBOM/VEX → sign-attest → verify → lock → read-only promotion, each gated to `refs/heads/main`; PR path is local build + Trivy only. Promotion emits the reviewed release artifact and has no direct cluster or repository write authority. |
| Trust-ref subtlety | `azure-sign-attest.yml` / `azure-verify.yml` | IMPLEMENTED_BUT_UNVERIFIED | `TRUSTED_REF`/`configSource.uri` are hardcoded to `refs/heads/main` regardless of the caller's ref. Mitigated in practice because the CI UAMI federation subject only lets `ref:refs/heads/main` callers obtain Azure credentials, but this should be explicitly confirmed in Task 0.3 (a caller on another ref could still reach the sign step and would fail only at `azure-auth`). |

## Tests

| Item | Classification | Finding |
| --- | --- | --- |
| Azure Kyverno test fixtures (unsigned, wrong-identity, init-container, mixed containers) | IMPLEMENTED_BUT_UNVERIFIED | Azure fixtures now include unsigned, mutable-tag, mixed/init-container, and deliberately invalid signer/provenance cases; the static policy contract covers them. |
| Python tests for the Azure Function | IMPLEMENTED_BUT_UNVERIFIED | The Function test module covers valid-event, priority, malformed-payload, missing-secret, and secret-safety paths. |
| Helm placeholder/release contract | IMPLEMENTED_BUT_UNVERIFIED | Static validation proves the base chart remains placeholder-safe and the promotion render produces an immutable digest image; a real release still requires a signed Azure image. |
| Existing GCP policy tests (`policy/tests/`) | IMPLEMENTED_BUT_UNVERIFIED | Must still pass unchanged; no Azure-specific assertions added there (correct — GCP tests stay GCP). |

## Documentation

| Item | Classification | Finding |
| --- | --- | --- |
| `docs/azure/01-architecture-decisions.md`, `02-setup.md`, `03-validation-checklist.md`, `README.md` | IMPLEMENTED_BUT_UNVERIFIED | Reconciled with the production root, staged private endpoint gate, daily maintenance, flow-log opt-in, Argo release-values convention, and live evidence. |
| Live validation checklist (`04-live-validation-checklist.md`) | IMPLEMENTED_BUT_UNVERIFIED | Exists with explicit static/live states, private-host prerequisites, evidence commands, and cleanup guardrails. |

## Prioritized gaps (input for Task 0.6 backlog)

1. **LIVE_VALIDATION_PENDING — trusted Azure release**: remote `main` still needs the approved Azure workflow path, then build/scan/sign/attest/verify/lock must produce a real ACR digest.
2. **LIVE_VALIDATION_PENDING — reviewed GitOps promotion**: add the generated `values.release.yaml` in an owner-reviewed change, then enable Argo automated sync only after its image is available.
3. **LIVE_VALIDATION_PENDING — private closure**: enable flow logs/private endpoints only after private DNS, storage, runner, and Function-host probes pass from the VNet.
4. **PARTIAL — image locking verification**: confirm `az acr repository update` digest-level locking works under the ABAC writer conditions.
5. **IMPLEMENTED_BUT_UNVERIFIED — parity static sweep**: offline Terraform, Helm, policy, Falco, GitOps, and workflow contracts pass; retain the recorded evidence update.
6. **BLOCKED_BY_EXTERNAL_INPUT — optional Discord alerting**: requires an owner-supplied webhook and explicit opt-in.

## Task 0.3 — Workflow security review (findings)

Scope reviewed with actual content: all Azure `azure-*.yml` workflows, the
`azure-auth` composite action, and the shared components they invoke
(`setup-cosign`, `setup-syft`, `sbom-vex.yml`). The original
review made no workflow changes.

| Check | Result | Evidence |
| --- | --- | --- |
| Triggers | PASS | Reusables are `workflow_call`-only; `azure-static-validation.yml` = PR/push/dispatch with static-only jobs; `azure-deploy.yml` = push(main)/PR(main)/dispatch with confirm input. |
| Trusted ref | PASS | Every release job gated `github.ref == 'refs/heads/main'`; `TRUSTED_REF` pinned to `refs/heads/main` in sign-attest/verify; Terraform federation subject is exactly `repo:devSatym/gcp-supply-chain-security:ref:refs/heads/main`. The gating pattern mirrors the live-validated GCP `deploy.yml` (including the dispatch `confirm == 'deploy'` guard and `needs`-based skip behavior). |
| Permissions | PASS | `id-token: write` appears only in the four workflows that call `azure-auth` (build-push, sign-attest, verify, lock) plus the orchestrator that calls them; `security-events: write` only where SARIF is uploaded; `sbom-vex.yml` and static validation are `contents: read`. No `packages`/`attestations`/`actions` grants anywhere. |
| OIDC | PASS | Issuer pinned to `https://token.actions.githubusercontent.com` in verify and the Kyverno attestor; signer identity pinned to `azure-sign-attest.yml@refs/heads/main`; provenance `entryPoint` derived from the signed OIDC token's `job_workflow_ref` and asserted before attesting (workflow constraint present). |
| PR boundary | PASS | PR runs: static validation (no `id-token`) and a local build+Trivy scan in `azure-deploy.yml` whose job-level permissions drop `id-token`; no PR path reaches `azure-auth`. Defense in depth: a PR OIDC token subject (`repo:...:pull_request`) cannot satisfy the UAMI federation subject even if gating regressed. |
| Digest propagation | PASS (build→lock→artifact) | `build-push.outputs.digest` → sign-attest → verify → lock → read-only `promote` artifact; Trivy scans by digest. A reviewed commit of the artifact remains an owner action before Argo sync. |
| Checkout behavior | PASS | All third-party actions are SHA-pinned with version comments; default checkout (`github.sha`) in call/push contexts means the trusted chain builds the pushed main commit; PR scan checks out the merge SHA locally only. |
| Reusable workflows | PASS | Typed required inputs; only non-secret `vars.*` passed; no `secrets.*` anywhere (grep-verified across all Azure files); single output `digest`; same-repo `./.github/workflows/...` references so called code comes from the caller's commit. |

Issues and observations (items 1–5 are resolved or intentional; items 6–8 are retained as operational notes):

1. `sbom-vex.yml` reuse from the Azure orchestrator is verified safe: it is registry-agnostic, offline (CycloneDX from source + depscan), `permissions: contents: read`, no `id-token`, no GCP authentication. This resolves the Task 0.2 "verify sbom-vex reuse" item.
2. `TRUSTED_REF`/`configSource.uri` hardcoding to `refs/heads/main` in sign-attest/verify is acceptable: Azure authority already requires a `refs/heads/main` caller via the federation subject, so a non-main caller cannot both obtain Azure credentials and produce a trusted attestation. Resolves the Task 0.2 "TRUSTED_REF" verification item.
3. `azure-deploy.yml` push trigger intentionally excludes `infrastructure/azure/**` — Terraform changes do not trigger image release. Correct separation; noted so it is not "fixed" later.
4. `azure-static-validation.yml` push trigger includes `feature/azure-implementation`. Static-only, so safe; remove after merge as hygiene.
5. `workflow_dispatch` without the `deploy` confirmation leaves the whole chain skipped (`needs` + ref gating, same proven pattern as GCP). Worst case is a skipped run, never a partial release.
6. The prior direct deploy gap is intentionally closed with a read-only promotion artifact; a reviewed commit of `values.release.yaml` remains an owner action before Argo sync.
7. `COSIGN_EXPERIMENTAL=1` legacy signature flow plus the separate mutable metadata repository is consistent with the Kyverno `repository:` override and the documented architecture decision.
8. `az acr login --expose-token` flow masks the short-lived token; the all-zero Docker username is the documented token-flow username, not an admin credential.

Conclusion: the PR security boundary and trusted-main release authority hold in
the current implementation. Live release promotion remains pending a real
signed image and an owner-reviewed GitOps values commit.

## Task 0.4 — Terraform architecture review (findings)

Scope: all seven Azure roots plus the usage example, their tfvars/backend
examples, and root READMEs. No Terraform was modified.

### Per-module review

| Module | Purpose | Dependencies (direction) | Major resources | Key inputs | Key outputs | Identities | Security boundary | Status / recommendation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `bootstrap-state` | One-time Terraform remote-state foundation | None (standalone root) | Resource group, StorageV2 account (keys disabled, AAD auth, firewall deny-by-default, versioning + soft delete), private container, operator role assignments | Names/location, allowed runner CIDRs/subnets, operator object IDs | Backend config (`use_azuread_auth`, `use_oidc`) | Caller/operator Entra principals (input) | State account unreachable except declared runners; no key-based access | IMPLEMENTED_BUT_UNVERIFIED — keep as-is; root config by design |
| `network` | Workload network boundary | None (produces everything downstream needs) | VNet, AKS-node + delegated API-server + private-endpoint + Functions subnets, NSGs, NAT GW + static PIP, Private Link DNS zones, opt-in flow logs | CIDRs, DNS zone names, flow-log opt-ins | Subnet/VNet/NAT/DNS IDs | — | No delegation on node subnet; explicit deny SSH/RDP; controlled NAT egress | IMPLEMENTED_BUT_UNVERIFIED — keep as-is |
| `aks` | Private cluster | Consumes `network` outputs (`vnet_id`, node + API-server subnets) | User-assigned control-plane identity, Network Contributor @ VNet, Log Analytics workspace, AKS cluster, user pools, optional kubelet ACR role | Subnet IDs, Entra admin groups, node pools, optional `acr_id` | `oidc_issuer_url`, `private_fqdn`, `kubelet_identity*`, host/CA (sensitive) | Control-plane UAMI (Network Contributor only); AKS-managed kubelet identity | Private API only, Azure RBAC, local accounts disabled, no public fallback | IMPLEMENTED_BUT_UNVERIFIED — keep as-is |
| `supply-chain` | ACR + all GitHub/K8s-facing registry identities | Consumes `aks.oidc_issuer_url` (+ optional kubelet principal) | Premium ACR (ABAC mode, admin/anonymous off), GitHub CI UAMI + `refs/heads/main` federation, Kyverno UAMI + AKS-SA federation, ABAC-scoped writer/reader roles, opt-in catalog listers | ACR name, repo paths, GitHub repo (pinned), AKS OIDC issuer | Login server, repo paths, CI/Kyverno client IDs, subject strings | GitHub CI UAMI (repo writer, 2 paths), Kyverno UAMI (repo reader, 2 paths), kubelet (reader, optional) | Exact-subject federation; ABAC conditions limit to the two repository paths; metadata repo separate from application repo | IMPLEMENTED_BUT_UNVERIFIED — keep single-module boundary (cohesive lifecycle: registry + its identities) |
| `kubernetes-addons` | Admission controller install | Consumes `supply-chain` outputs (client ID, login server, repo paths); helm/k8s providers from caller; renders `policy/azure/kyverno/*` templates | Kyverno Helm release (pinned 3.9.0), ClusterPolicy manifest, optional metrics-server, pinned Argo CD foundation | `kyverno_client_id`, ACR coordinates, chart versions | Release/policy status | (consumes Kyverno UAMI client ID) | Two-phase apply documented for CRD ordering; unrendered templates are inert; Argo is ClusterIP-only with no ingress | IMPLEMENTED_AND_VALIDATED — live private-cluster proof recorded |
| `falco` | Runtime sensors + sidekick routing | Consumes `falco-alerting` outputs (Event Hub FQDN/name, sidekick client ID) when alerting enabled | Namespace, pinned Falco Helm release (9.1.0) with Falcosidekick workload-identity config | Driver kind, Event Hub coordinates, priorities, custom rules | Namespace, release status | (consumes Falcosidekick UAMI client ID) | modern_ebpf default; no connection strings in cluster | IMPLEMENTED_AND_VALIDATED — live sensor and custom-rule proof recorded |
| `falco-alerting` | Optional alerting plane | Consumes AKS OIDC issuer (federation) | Event Hub namespace/hub (SAS disabled), Falcosidekick UAMI + federation, Key Vault (RBAC, purge protection) + write-only webhook secret, Function storage/plan/app, archive zip, receiver/secrets-user/host-storage roles | Prefix, OIDC issuer, SA subject, Discord webhook (`TF_VAR_`, write-only) | Event Hub/identity/Function/KV URI outputs | Falcosidekick UAMI (Data Sender), Function system identity (Receiver + Secrets User + host-storage) | Alerting opt-in; webhook never in state; roles scoped to single resources | IMPLEMENTED_BUT_UNVERIFIED — keep; role breadth review deferred to Task 4.2 |

### Boundary assessment

- The dependency direction is strictly layered with no cycles:
  `bootstrap-state` (standalone) → `network` → `aks` → `supply-chain` →
  (`kubernetes-addons`, `falco`) with `falco-alerting` feeding `falco`.
  Every inter-module hand-off is documented in READMEs and tfvars examples as
  output-to-input wiring; nothing imports state or hardcodes another module's
  resource names.
- The reusable child modules are composed by
  `infrastructure/azure/environments/prod/` in the documented dependency
  order. The root is statically validated; its Helm/provider stages still
  require a private-network host for live execution.
- Cross-tree template dependency (`kubernetes-addons` renders
  `policy/azure/kyverno/*` via `path.module/../../../policy/...`) is acceptable
  in this monorepo and keeps a single source of truth for the trust contract;
  note that it makes the root repo-layout-dependent.

### Consistency findings (repairs for a later phase, not now)

1. **README output-name drift**: `supply-chain/README.md` and `aks/README.md`
   usage snippets reference `module.aks.kubelet_identity_principal_id`, but the
   aks module actually outputs `kubelet_identity_object_id` (and the map
   `kubelet_identity`). Small doc fix required before the environment root is
   written so wiring examples are copy-correct.
2. **Lock-scope deviation**: `supply-chain/README.md` says to lock "both the
   release SHA tag and its manifest digest", while `azure-lock-image.yml` locks
   only the digest reference. Digest-only deployments (Kyverno `verifyDigest`,
   digest-pinned chart) make the digest lock sufficient for the trust chain;
   either add the tag lock or amend the README so documented behavior matches
   implementation.
3. **Example region inconsistency**: bootstrap/network/aks examples use
   `centralindia`, the supply-chain example uses `westeurope` (all placeholders;
   cosmetic, but pick one placeholder region for coherence).
4. **Naming collision note**: GCP's `infrastructure/falco-alerting/` and
   Azure's `infrastructure/azure/falco-alerting/` share a basename but live in
   distinct trees; no conflict, just keep imports careful.

## Task 0.5 — Secret / generated file review (findings)

Pattern scan across `infrastructure/azure`, `policy/azure`, `k8s/azure`, the
Azure Argo app, Azure workflows/actions, and `docs/azure` for client secrets,
passwords, connection strings, account keys, private keys, API keys, webhook
URLs, state files, kubeconfigs, and non-example tfvars. No secret values are
printed here.

| File | Location | Category | Result / remediation |
| --- | --- | --- | --- |
| `infrastructure/azure/**/.terraform/` (8 dirs) | provider caches | Generated binary cache | Matches secret-pattern greps only as binary noise; remove from the repo tree during Phase 1 (regenerable, never commit) |
| `infrastructure/azure/*/.terraform.lock.hcl` (8) | provider locks | Generated lock file | Safe, credential-free; decision recorded in backlog (recommended: commit for reproducible provider pins) |
| `.github/actions/azure-auth/action.yml:51` | `password:` input of docker-login step | Short-lived ACR access token | By design: `--expose-token` Entra token, `::add-mask::` applied, zero-GUID username; no remediation |
| `falco-alerting/README.md:18`, `docs/azure/02-setup.md:89` | `TF_VAR_discord_webhook_url` export examples | Webhook URL placeholder | Literal `REPLACE_ME` only; correct pattern (env var → write-only Key Vault); no remediation |
| `function_app.py` | webhook cache variable | Secret-handling code | Runtime-only Key Vault retrieval; value never logged; no remediation |
| repo root `cosign-linux-amd64` | binary (~19.8 MB) | Downloaded tool | Not referenced by any Azure asset; keep excluded from all import allowlists |
| tfvars examples (4) | placeholder CIDRs/GUIDs (`203.0.113.10/32`, zero GUIDs) | Example values | Documentation-range/zero placeholders; no real identifiers |

No Terraform state, kubeconfig, real tfvars, certificate/key files, or literal
credentials were found in any Azure asset. `docs/my-validation/`, `plan.md`,
`plan-2.md`, `docs/codex/12.md` remain non-importable personal/local material.

## What is NOT a gap (deliberate, documented decisions)

- Single `supply-chain` module instead of separate ACR/identity modules (AGENT.md 0.4).
- Separate mutable Cosign metadata repository instead of OCI referrers (compatibility path documented).
- Public-network bootstrap posture with explicit staged switch to private endpoints.
- Placeholder-based chart/policy sources that cannot match real images unrendered.
- CLI-based image locking instead of a nonexistent Terraform control.
