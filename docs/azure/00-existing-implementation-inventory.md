# 00 — Existing implementation inventory (Task 0.1)

Inventory of Azure-related and adjacent material currently in the worktree.
Recorded on 2026-08-29. This is an inventory only: no correctness judgment is
made here. Detailed review belongs to Task 0.2 (gap assessment).

Classification values used below:

- `EXISTING_IMPLEMENTATION` — appears to be actual candidate Azure implementation.
- `POSSIBLE_SUPPORTING_FILE` — README, examples, tfvars examples, ignore files.
- `UNRELATED` — not part of the Azure implementation.
- `GENERATED_OR_LOCAL_ARTIFACT` — binary, provider cache, lock file, local plan, personal evidence.
- `NEEDS_REVIEW` — role or safety not yet established.

## Repository state observed

- Branch: `feature/azure-implementation` at `3debc26` (an ancestor of `origin/main`; main is at `35e68d6`).
- Uncommitted changes: 11 modified tracked files plus a large untracked Azure candidate implementation (see sections below).
- Other worktrees: two prunable entries (`docs/readme-redesign`, `screenshot/pr-security-gates`) whose gitdirs no longer exist. No additional candidate Azure implementation found in other worktrees.
- Governing local plan files: `AGENT.md`, `glm-plan.md` (both untracked).

## Terraform

All files below are **untracked**. Seven independent roots (each has its own
`versions.tf`): `bootstrap-state`, `network`, `aks`, `supply-chain`,
`kubernetes-addons`, `falco`, `falco-alerting`.

| Path | Class | Purpose (apparent) | Notes |
| --- | --- | --- | --- |
| `infrastructure/azure/bootstrap-state/` (main/variables/outputs/versions.tf) | EXISTING_IMPLEMENTATION | Terraform remote-state bootstrap root; Azure AD data-plane auth (`storage_use_azuread = true`) with storage keys disabled | Root config, not a module; azurerm `>= 4.44, < 5` |
| `infrastructure/azure/bootstrap-state/backend.hcl.example` | POSSIBLE_SUPPORTING_FILE | Example backend configuration for state storage | |
| `infrastructure/azure/network/` | EXISTING_IMPLEMENTATION | VNet/subnet implementation for private AKS networking | azurerm `>= 4.44, < 5` |
| `infrastructure/azure/aks/` | EXISTING_IMPLEMENTATION | Private AKS cluster root | azurerm `>= 4.44, < 5` |
| `infrastructure/azure/supply-chain/` | EXISTING_IMPLEMENTATION | Combined ACR + identities + federated-credential module (single-module boundary; see `AGENT.md` 0.4) | azurerm `>= 4.70, < 5`; required TF `>= 1.11` |
| `infrastructure/azure/supply-chain/examples/complete/` | POSSIBLE_SUPPORTING_FILE | Usage example calling `../..`; declares its own provider block | Has its own `.terraform` artifacts (below) |
| `infrastructure/azure/kubernetes-addons/` | EXISTING_IMPLEMENTATION | Helm/Kubernetes add-ons root (apparent Kyverno/workload-identity add-ons) | helm `>= 2.13`, kubernetes `>= 2.30`; no cloud provider — needs deeper review of how cluster config is supplied |
| `infrastructure/azure/falco/` | EXISTING_IMPLEMENTATION | Falco/Falcosidekick Helm root | helm + kubernetes providers |
| `infrastructure/azure/falco-alerting/` | EXISTING_IMPLEMENTATION | Event Hubs + Function relay + Key Vault write-only webhook root | azurerm `>= 4.29` + archive `>= 2.4`; contains `functions/discord-notifier/` payload |
| `infrastructure/azure/*/README.md` (7 files) | POSSIBLE_SUPPORTING_FILE | Per-root documentation | |
| `infrastructure/azure/{aks,network,bootstrap-state,supply-chain}/terraform.tfvars.example` | POSSIBLE_SUPPORTING_FILE | Example variable values | `.example` only; no real tfvars found |
| `infrastructure/azure/falco-alerting/.gitignore` | POSSIBLE_SUPPORTING_FILE | Local ignore for the alerting root | |

Generated artifacts already present inside the untracked tree (recorded, not
deleted, in this task):

| Path | Class | Notes |
| --- | --- | --- |
| `infrastructure/azure/*/.terraform.lock.hcl` (7 roots + example) | GENERATED_OR_LOCAL_ARTIFACT | Provider lock files created by earlier in-place `terraform init`; decide in a later task whether to commit or remove |
| `infrastructure/azure/*/.terraform/` (7 roots + example) | GENERATED_OR_LOCAL_ARTIFACT | Provider caches; must not be committed; removal is a later task |

## Networking

- Covered by `infrastructure/azure/network/` (above). No separate network modules or hard-coded environment values observed at inventory level.

## AKS

- Covered by `infrastructure/azure/aks/` (above). Privacy/OIDC/workload-identity settings not judged in this task.

## Supply Chain (ACR, signing, identity, SBOM/provenance)

- Terraform side: `infrastructure/azure/supply-chain/` (ACR + identity + federation, combined module).
- Workflow side: `azure-build-push.yml`, `azure-sign-attest.yml`, `azure-verify.yml`, `azure-lock-image.yml` (below).
- No separate cosign/SBOM Terraform modules found.

## GitHub OIDC

| Path | Tracked? | Class | Purpose | Notes |
| --- | --- | --- | --- | --- |
| `.github/actions/azure-auth/action.yml` | untracked | EXISTING_IMPLEMENTATION | Composite action "Azure OIDC and ACR Login" | OIDC-only claim to be verified in Task 0.3 |
| `.github/actions/gcp-auth/action.yml`, `docker-login/`, `setup-cosign/`, `setup-syft/` | tracked | EXISTING_IMPLEMENTATION (shared/GCP) | Existing composite actions used by GCP workflows | Do not modify |

## GitHub Actions — Azure workflows (all untracked)

| Workflow | Triggers observed | Apparent role | Class |
| --- | --- | --- | --- |
| `.github/workflows/azure-static-validation.yml` | `pull_request`, `push` | Offline/static checks for Azure changes | EXISTING_IMPLEMENTATION |
| `.github/workflows/azure-build-push.yml` | `workflow_call` | Reusable build/push to ACR | EXISTING_IMPLEMENTATION |
| `.github/workflows/azure-sign-attest.yml` | `workflow_call` | Reusable Cosign sign + SBOM/provenance attest | EXISTING_IMPLEMENTATION |
| `.github/workflows/azure-verify.yml` | `workflow_call` | Reusable independent verification of attestations | EXISTING_IMPLEMENTATION |
| `.github/workflows/azure-lock-image.yml` | `workflow_call` | Reusable image lock after verification | EXISTING_IMPLEMENTATION |
| `.github/workflows/azure-deploy.yml` | `push`, `pull_request` | Deploy to AKS | NEEDS_REVIEW — PR trigger on a deploy workflow requires scrutiny in Task 0.3 |

Tracked GCP counterparts (`build-push.yml`, `deploy.yml`, `sign-attest.yml`,
`verify.yml`, `pr-check.yml`, `security-scan.yml`, `sbom-vex.yml`,
`infrastructure-terraform.yml`) are existing GCP implementation and are out of
scope for modification.

## Kyverno

| Path | Tracked? | Class | Purpose |
| --- | --- | --- | --- |
| `policy/azure/kyverno/block-unsigned-images.yaml` | untracked | EXISTING_IMPLEMENTATION | Azure Kyverno ClusterPolicy (signature/digest verification) |
| `policy/azure/kyverno/values.yaml` | untracked | EXISTING_IMPLEMENTATION | Helm values for Kyverno on Azure |
| `policy/azure/kyverno/README.md` | untracked | POSSIBLE_SUPPORTING_FILE | Policy documentation |

Tracked GCP policies (`policy/kyverno/`, `policy/gatekeeper/`,
`policy/test-manifests/`, `policy/tests/`) remain untouched GCP implementation.

## Kubernetes / Helm

| Path | Tracked? | Class | Purpose |
| --- | --- | --- | --- |
| `k8s/azure/supply-chain-demo/Chart.yaml` | untracked | EXISTING_IMPLEMENTATION | Azure demo app chart |
| `k8s/azure/supply-chain-demo/values.yaml` | untracked | EXISTING_IMPLEMENTATION | Chart values (ACR references expected) |
| `k8s/azure/supply-chain-demo/templates/{deployment,service}.yaml`, `templates/_helpers.tpl` | untracked | EXISTING_IMPLEMENTATION | Workload templates |
| `k8s/azure/README.md` | untracked | POSSIBLE_SUPPORTING_FILE | Chart documentation |

## Argo CD

| Path | Tracked? | Class | Purpose |
| --- | --- | --- | --- |
| `argocd/supply-chain-azure-demo-app.yaml` | untracked | EXISTING_IMPLEMENTATION | Argo CD Application for the Azure demo |
| `argocd/supply-chain-demo-app.yaml`, `argocd/supply-chain-test-negative-app.yaml` | tracked | EXISTING_IMPLEMENTATION (GCP) | Existing GCP GitOps apps; do not modify |

## Falco / Runtime Security

- `infrastructure/azure/falco/` (Terraform root above) — Falco/Falcosidekick deployment.

## Event Hubs / Alerting

- `infrastructure/azure/falco-alerting/` (Terraform root above) — Event Hubs namespace/hub, Key Vault webhook secret (write-only), Discord relay Function.

## Azure Functions

| Path | Tracked? | Class | Purpose |
| --- | --- | --- | --- |
| `infrastructure/azure/falco-alerting/functions/discord-notifier/function_app.py` | untracked | EXISTING_IMPLEMENTATION | Function relay payload (Discord notifier) |
| `infrastructure/azure/falco-alerting/functions/discord-notifier/host.json` | untracked | POSSIBLE_SUPPORTING_FILE | Functions host config |
| `infrastructure/azure/falco-alerting/functions/discord-notifier/requirements.txt` | untracked | POSSIBLE_SUPPORTING_FILE | Python dependencies |

## Tests

- No Azure-specific test files were found (`tests/` and `scripts/` directories do not exist at repo root).
- `policy/tests/` (tracked; `check-identity-consistency.sh`, `test_jmespath_conditions.py`, fixtures) and `policy/test-manifests/` are existing GCP-oriented policy tests; the Azure checklist expects them to still pass.
- No unit tests yet for `infrastructure/azure/falco-alerting/functions/discord-notifier/function_app.py` (the Azure checklist lists this as pending).
- No Azure Kyverno test fixtures yet (GCP ones exist under `policy/test-manifests/`).

## Documentation

| Path | Tracked? | Class | Purpose |
| --- | --- | --- | --- |
| `docs/azure/README.md` | untracked | EXISTING_IMPLEMENTATION | Azure documentation index |
| `docs/azure/01-architecture-decisions.md` | untracked | EXISTING_IMPLEMENTATION | Azure architecture decisions |
| `docs/azure/02-setup.md` | untracked | EXISTING_IMPLEMENTATION | Azure setup guide |
| `docs/azure/03-validation-checklist.md` | untracked | EXISTING_IMPLEMENTATION | Validation/evidence checklist (static + live sections) |
| `docs/azure/00-existing-implementation-inventory.md` | untracked | EXISTING_IMPLEMENTATION | This document (Task 0.1 deliverable) |
| `docs/codex/03-VALIDATION.md` | tracked, **modified** | NEEDS_REVIEW | Pre-existing uncommitted edit (~49 lines removed) |
| `docs/codex/12.md` | untracked | UNRELATED | Prior chat transcript about GCP screenshot workflow |
| `docs/my-validation/*.png` (13 files) | untracked | UNRELATED / personal evidence | GCP validation screenshots; must not be reused as Azure evidence |

## Uncommitted modifications to tracked (shared/GCP) files

Pre-existing in the worktree before Task 0.1; not made by this task; no changes
made to them here.

| Path | Class | Observation |
| --- | --- | --- |
| `.gitignore` | NEEDS_REVIEW | Adds ignores for `LOCAL_ENVIRONMENT.md`, `.env`, `.env.*` (keeps `!.env.example`) |
| `infrastructure/environments/prod/{README.md,falco-alerting.tf,terraform.tfvars.example,variables.tf,versions.tf}` | NEEDS_REVIEW | GCP prod root edits; `versions.tf` bumped to `>= 1.11.0` with write-only-value comment |
| `infrastructure/falco-alerting/{READM.md,main.tf,variables.tf,versions.tf}` | NEEDS_REVIEW | GCP alerting root edits (distinct from the new `infrastructure/azure/falco-alerting/`) |

## Generated / Local / Suspicious Files

| Path | Class | Size/notes | Security concern |
| --- | --- | --- | --- |
| `cosign-linux-amd64` | GENERATED_OR_LOCAL_ARTIFACT | ~19.8 MB downloaded binary at repo root | Must not enter source control; excluded from any import allowlist |
| `plan.md`, `plan-2.md` | UNRELATED | Older GCP README/planning prompts | Exclude from implementation |
| `AGENT.md`, `glm-plan.md` | POSSIBLE_SUPPORTING_FILE | Active local governing plans for this effort | Not implementation; not evidence |
| `infrastructure/azure/*/.terraform/` | GENERATED_OR_LOCAL_ARTIFACT | Provider caches in all 7 roots + example | Must not be committed |
| `infrastructure/azure/*/.terraform.lock.hcl` | GENERATED_OR_LOCAL_ARTIFACT | Provider lock files | Decide commit-vs-remove in a later task |
| `docs/my-validation/*.png` | UNRELATED | GCP evidence screenshots | Never present as Azure evidence |

## Additional Candidate Work

None found. Both non-primary worktrees are prunable (gitdirs under `/tmp` no
longer exist) and contained documentation/screenshot branches, not Azure
implementation.

## Initial Summary

- Already implemented (candidate, unverified): 7 Terraform roots under `infrastructure/azure/`, 1 usage example, Azure OIDC composite action, 6 Azure workflows (5 reusable/static + 1 deploy needing review), Azure Kyverno policy + values, Azure Helm chart, Azure Argo CD application, Function relay payload, 4 Azure docs.
- Apparently partial: test coverage (no Azure Python/Kyverno/Helm tests yet); `.terraform.lock.hcl` handling undecided; `.terraform/` caches present in-repo.
- Needs deeper validation: everything above is at best IMPLEMENTED_BUT_UNVERIFIED; no static validation results are recorded yet in `docs/azure/03-validation-checklist.md` (all boxes unchecked). Workflow trust/PR boundaries (esp. `azure-deploy.yml` PR trigger) need Task 0.3 review.
- Apparently missing: Azure-specific test suites, live-validation checklist (`04-live-validation-checklist.md`), any recorded static validation evidence.
- Generated/local artifacts: `cosign-linux-amd64` binary, 8 `.terraform/` caches, 8 lock files, 13 personal GCP screenshots, 2 old plan prompts, 1 transcript file.
