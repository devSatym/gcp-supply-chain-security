# 02 — Implementation backlog (Task 0.6)

Only actual remaining work, derived from `01-gap-assessment.md` (Tasks 0.2–0.5).
Nothing here duplicates existing, coherent implementation. Items are ordered by
dependency.

## B1 — Static validation sweep and repair (Phase 1.2/1.3) — DONE 2026-08-29

- Component: all 7 Terraform roots + usage example.
- Existing implementation: complete candidate code; only `bootstrap-state` has a recorded init/validate pass.
- Issue: no full fmt/init/validate evidence recorded.
- Required change: run `terraform fmt -check -recursive infrastructure/azure`, then `terraform init -backend=false` + `terraform validate` per root from temporary copies; repair only fmt/syntax/provider-version/variable-validation failures; re-run exactly the failing check; remove in-repo `.terraform/` caches.
- Files: `infrastructure/azure/**` (repairs only if a check fails); `docs/azure/03-validation-checklist.md` (results).
- Dependency: none (first).
- Validation: the commands above + `git diff --check`.
- Security impact: low; proves the code parses and provider schemas match.
- Priority: P0.

## B2 — Production environment root `infrastructure/azure/environments/prod/` (Phase 1) — DONE 2026-08-29 (validated: init/validate PASS; staged-apply README; private-endpoint stage-3 gate)

- Component: composing root referenced by `docs/azure/02-setup.md` and `azure-static-validation.yml`.
- Existing implementation: all child modules exist with documented output→input wiring.
- Issue: no root composes network → AKS → supply-chain → add-ons → falco → falco-alerting; nothing flips ACR/Key Vault/Event Hubs/Function-storage to private endpoints / `public_network_access_enabled = false`.
- Required change: create the root (providers with private-cluster kubeconfig path, module blocks in documented order, tfvars example, README with the staged apply sequence and private-endpoint finish line).
- Files: new `infrastructure/azure/environments/prod/{versions,main,variables,outputs}.tf`, `terraform.tfvars.example`, `README.md`.
- Dependency: B1 (validated child modules); private AKS API means Helm/Kubernetes provider stages need the documented private-runner caveat.
- Validation: `terraform fmt -check`, `terraform init -backend=false`, `terraform validate`; static workflow picks the directory up automatically.
- Security impact: high — this is where public network access is turned off permanently.
- Priority: P0.

## B3 — Digest promotion / reviewed GitOps release values — IMPLEMENTED 2026-08-30

The Azure Argo CD Application now consumes `values.release.yaml`, while
`syncPolicy.automated` remains disabled until that file is added by an
owner-reviewed promotion change. Current state:

- The trusted-main `promote` job has read-only repository permissions and
  emits `values.release.yaml` plus a rendered manifest as an evidence
  artifact after verify and image locking.
- The checked-in base values remain unresolved placeholders and cannot be
  synchronized into a workload.
- Argo automation may be restored only after an owner-approved reviewed change
  adds the generated file containing only the verified and locked digest.

- Component: release chain after `lock-verified-image`.
- Existing implementation: `azure-deploy.yml` renders and uploads the verified release values; Argo is installed privately by the add-ons module.
- Remaining action: owner-reviewed promotion of the generated file and live Argo sync after a real image exists.
- Files: `.github/workflows/azure-deploy.yml`, `k8s/azure/supply-chain-demo/values.release.yaml.example`, `argocd/supply-chain-azure-demo-app.yaml`.
- Dependency: a trusted Azure main workflow run producing a real signed/locked ACR digest and an owner-approved GitOps change.
- Validation: workflow YAML parse + policy/Falco/GitOps contract tests; live promotion stays BLOCKED_BY_EXTERNAL_INPUT.
- Security impact: high — preserves verify → lock → reviewed GitOps release without direct cluster mutation.
- Priority: P1.

## B4 — Azure Kyverno test fixtures (Phase 2.1/2.5) — DONE 2026-08-29

- Component: admission policy tests.
- Existing implementation: Azure ClusterPolicy template + GCP fixtures under `policy/test-manifests/`.
- Issue: no Azure negative/positive fixtures (unsigned, wrong workflow identity, init-container bypass, valid digest).
- Required change: add Azure fixtures mirroring the GCP set with ACR references and wire a render+assert step (policy template → concrete values → fixture expectations) into static validation.
- Files: new `policy/azure/test-manifests/*.yaml`, optional runner script, `.github/workflows/azure-static-validation.yml`.
- Dependency: none.
- Validation: YAML parse + static assertions (and `kyverno apply` where the CLI is available).
- Security impact: medium — proves admission rules actually reject the documented bypass attempts.
- Priority: P1.

## B5 — Azure Function unit tests (Phase 2.4/2.5) — DONE 2026-08-29

- Component: `functions/discord-notifier/function_app.py`.
- Existing implementation: relay logic complete; no tests.
- Issue: checklist requires Python compilation and unit tests for valid event / missing-secret / malformed-payload paths.
- Required change: add unit tests with stubbed `azure.functions`/`azure.identity`/`azure.keyvault.secrets` modules (no SDK install needed) covering: valid event posts embed; priority filter; malformed payload dropped; missing Key Vault env/secret fails without logging the webhook.
- Files: new `infrastructure/azure/falco-alerting/functions/discord-notifier/test_function_app.py`.
- Dependency: none.
- Validation: `python3 -m pytest` (or unittest) locally and in the static workflow.
- Security impact: medium — locks the no-secret-logging behavior in.
- Priority: P1.

## B6 — Documentation consistency repairs (Phase 1.3-adjacent) — DONE 2026-08-29

- Component: root READMEs and examples.
- Existing implementation: coherent docs with two drifts found in Task 0.4.
- Issue: (a) usage snippets cite `module.aks.kubelet_identity_principal_id` but the real output is `kubelet_identity_object_id`; (b) supply-chain README says lock tag+digest while the workflow locks digest only; (c) placeholder region differs across examples.
- Required change: fix output name, align the lock wording with the implemented digest lock (or add the tag lock to `azure-lock-image.yml` as an explicit decision), normalize the placeholder region.
- Files: `infrastructure/azure/{supply-chain,aks}/README.md`, possibly `azure-lock-image.yml`, example tfvars.
- Dependency: none.
- Validation: `git diff --check`; grep for the wrong output name.
- Security impact: low; prevents broken copy-paste wiring in B2.
- Priority: P2.

## B7 — Provider lock files decision — DECIDED 2026-08-29: commit root lock files; example lock dropped only if the example stays cache-free (locks currently retained in-tree, `.terraform/` caches removed)

- Component: `.terraform.lock.hcl` files (8).
- Existing implementation: lock files exist from earlier in-place init.
- Issue: unrecorded decision to commit or drop.
- Required change: recommend committing the root lock files (reproducible provider pins across CI and operators); drop the `supply-chain/examples/complete` lock if examples stay cache-free.
- Files: `infrastructure/azure/*/.terraform.lock.hcl`.
- Dependency: B1 (lock files regenerated there if dropped).
- Validation: `git diff --check` after decision; CI `init` uses them.
- Security impact: low; supply-chain reproducibility benefit.
- Priority: P2.

## B8 — Live validation checklist (`docs/azure/04-live-validation-checklist.md`) (Phase 4.3) — DONE 2026-08-29

- Component: live deployment documentation.
- Existing implementation: `03-validation-checklist.md` has live sections; the dedicated live checklist with required external inputs does not exist yet.
- Required change: create the checklist distinguishing STATICALLY_VALIDATED / LIVE_VALIDATION_PENDING / LIVE_VALIDATED with subscription/tenant/region/prefix, bootstrap authority, GitHub variables, private-runner, plan/apply order, admission/runtime tests, evidence, cleanup.
- Files: new `docs/azure/04-live-validation-checklist.md`.
- Dependency: B2 (final module order).
- Validation: review only.
- Security impact: medium — prevents accidental live runs without explicit authorization.
- Priority: P2.

## Explicitly blocked (external inputs required — do not improvise)

- Any `terraform plan/apply` against Azure, AKS deployment, image push/sign/lock, Falco trigger test, Discord delivery: require subscription, tenant, authorized bootstrap principal, GitHub variables, private-network runner, and (optionally) `TF_VAR_discord_webhook_url`.
