# Azure implementation plan — reconciled starting point

## Decision: where implementation starts

Start from local branch plan/azure-glm53-implementation at fb94f793b8f2e9225f5ee271ae4e019cc3991a0c, which tracks origin/main.

Do not start from:

- main: it is stale at 35e68d6.
- feature/azure-implementation: its committed tip 3debc26 is an ancestor of origin/main and misses merged CI hardening.
- the former plan base 9933aea: it is on a sibling branch and also misses the merged CI hardening.

Remote refs were refreshed on 2026-08-29. Origin/main is current at fb94f79. It includes the existing feature branch's committed history, PR security gates, trusted-main hardening, and the latest merged documentation.

## Important local discovery

The current feature/azure-implementation worktree has a large uncommitted Azure candidate implementation. It already includes:

- Azure Terraform roots/modules for state, networking, AKS, supply chain, Kyverno add-ons, Falco, and Falco alerting.
- Azure Kyverno policy and Helm chart values.
- Azure OIDC composite action and seven Azure GitHub workflows.
- Azure Argo CD application manifest and Python Functions relay.
- Unrelated or non-Azure tracked edits, documentation/evidence files, plans, and a cosign-linux-amd64 binary.

This work is not committed and is not proof of correctness. Treat it as a reviewable source of candidate changes, not as a clean baseline and not as a reason to recreate modules.

## Safety and branch workflow

Never reset, stash, stage, commit, delete, or reformat the current dirty worktree.

Create a clean implementation worktree:

    git worktree add ../gcp-supply-chain-security-azure plan/azure-glm53-implementation
    cd ../gcp-supply-chain-security-azure
    git status --short

The clean worktree is the only place GLM should edit. The dirty worktree is a read-only source during reconciliation.

Before copying any work, create an allowlist of Azure paths. Candidate allowlist:

    infrastructure/azure/
    policy/azure/
    k8s/azure/
    argocd/supply-chain-azure-demo-app.yaml
    .github/actions/azure-auth/
    .github/workflows/azure-*.yml
    docs/azure/

Explicitly exclude and do not import until separately reviewed:

    cosign-linux-amd64
    plan.md
    plan-2.md
    docs/my-validation/
    docs/codex/
    .gitignore
    infrastructure/environments/prod/
    infrastructure/falco-alerting/

## GLM 5.3 Flash contract

Give GLM exactly one numbered task at a time.

For every task GLM must:

1. Read this file, git status --short, and only task-named files.
2. Stop if the clean worktree has unrelated changes; report paths and never clean them.
3. Make only the requested edit; never use broad rewrites, guessed cloud values, real credentials, or generated lock files.
4. Run the stated validation and report the exact command/result.
5. Run git diff --check and inspect the touched-file diff.
6. Mark a task complete only after its validation passes. Do not commit unless explicitly asked.

Stop and record a blocker if Azure subscription, tenant, region, globally unique prefix, RBAC authority, GitHub configuration, private-network runner, or Discord webhook is required. Never invent one.

## Security invariants

1. GitHub Actions uses OIDC only. No client secret, service-principal password, ACR admin account, kubeconfig, storage key, Event Hubs connection string, or webhook may enter source, tfvars, state config, or logs.
2. Trusted release ref is refs/heads/main. PR/feature workflows have static validation only.
3. AKS stays private. Never use a public API fallback.
4. Deploy immutable registry/repository@sha256 references only.
5. Lock application release images only after all verification; keep Cosign metadata separate and mutable.
6. Discord is opt-in and passed only through TF_VAR_discord_webhook_url to a write-only Key Vault field.
7. Do not modify GCP workflow trust settings or relabel GCP evidence as Azure evidence.

## Execution queue

### Phase 0 — Reconcile existing work before implementation

- [ ] 0.1 Inventory candidate work. In the dirty worktree, list every changed/untracked file and classify it as allowlist import, excluded, or needs human decision. Create docs/azure/00-wip-inventory.md in the clean worktree. No candidate code is copied.
- [ ] 0.2 Compare candidate files with origin/main baseline and this plan. Create docs/azure/01-gap-assessment.md with: implemented, partial, absent, incorrect/unverified; include exact file paths and validation needed. Do not judge by filenames alone.
- [ ] 0.3 Review the seven candidate workflows against existing trusted GCP workflows. Check triggers, permissions, OIDC, trusted ref, digest propagation, PR cloud authority, reusable-workflow inputs, and checkout/ref behavior. Record findings in the gap assessment.
- [ ] 0.4 Review candidate Terraform module boundaries. The candidate uses a supply-chain module rather than separate ACR/identity modules. Decide whether that boundary is coherent and document it; do not split modules merely to match an older plan.
- [ ] 0.5 Review secrets and generated files. Confirm the candidate has no credential, connection string, webhook, state, local provider directory, or binary to import. The cosign binary remains excluded.
- [ ] 0.6 Produce a file-level import manifest in docs/azure/02-import-manifest.md. Each allowed file needs a reason, dependency order, and validation command. Stop for human direction if an excluded file is needed.

### Phase 1 — Import and establish static validation

- [ ] 1.1 Import only the smallest reviewed foundation set from the manifest: bootstrap-state, network, AKS, and their required docs/examples. Preserve source paths and make no behavior changes during import.
- [ ] 1.2 Run terraform fmt -check -recursive on imported Azure Terraform. For each independent root, run terraform init -backend=false and terraform validate. Record all results in docs/azure/03-validation.md.
- [ ] 1.3 Fix only formatting, syntax, provider-version, variable-validation, and backend-free validation failures found in 1.2. Re-run exactly the failing check.
- [ ] 1.4 Import reviewed ACR/supply-chain and identity resources. Verify admin/anonymous access is disabled, repository roles are scoped, GitHub federation subject is exact main, and workload federations use AKS OIDC. Validate Terraform.
- [ ] 1.5 Verify the image-lock implementation against current AzureRM/API support. If unsupported, replace it with a documented post-verification command; do not claim Terraform enforcement that does not exist.

### Phase 2 — Policy, manifests, and runtime components

- [ ] 2.1 Import Kyverno values/policy and tests. Verify Azure ACR host, digest-only image rule, exact GitHub issuer/repository/main/workflow/entrypoint constraints, signature, SPDX, and SLSA checks. Parse YAML and run policy tests.
- [ ] 2.2 Import Azure Helm/Argo manifests. Verify ACR digest references, namespace, security context, and no GCR/GAR identity leakage. Parse/render YAML.
- [ ] 2.3 Import Falco module/values. Verify eBPF compatibility and Falcosidekick Event Hubs workload identity using DefaultAzureCredential, never connection strings. Validate Terraform/YAML.
- [ ] 2.4 Import alerting resources and Function relay. Verify alerting defaults disabled; webhook is write-only; roles are narrowly scoped; logs redact secrets; relay tests cover valid event and missing secret. Validate Terraform and unit tests.
- [ ] 2.5 Add or repair only the missing tests/fixtures identified by the gap assessment.

### Phase 3 — CI/CD reconciliation

- [ ] 3.1 Import azure-auth action and static validation workflow. Confirm PRs run only offline checks and cannot Azure-login, push, sign, mutate Git, or deploy.
- [ ] 3.2 Import build/push, sign/attest, verify, lock, and deploy workflows one at a time. After each import, compare it with the corresponding GCP workflow and run available YAML/static checks.
- [ ] 3.3 Verify the release chain end-to-end by inspection: canonical main -> SHA tag -> digest -> sign/SBOM/provenance -> independent verification -> lock -> private-runner digest deployment.
- [ ] 3.4 Add static contract tests for trusted ref, minimal OIDC permissions, digest deployment, no PR cloud authority, and no GCP workflow changes.

### Phase 4 — Completion gate

- [ ] 4.1 Run all Terraform, YAML, policy, workflow, Python, secret-pattern, and git diff --check validations. Record exact commands/results.
- [ ] 4.2 Review every role assignment and workflow permission for least privilege.
- [ ] 4.3 Create docs/azure/04-live-validation-checklist.md: required subscription/tenant/region/prefix, bootstrap authority, GitHub variables, private-network runner, plan/apply order, admission tests, Falco test, evidence, cleanup.
- [ ] 4.4 Do not run cloud commands until external inputs and authority are explicitly supplied. Then run a non-destructive Terraform plan before every apply and record Azure-only evidence.

## Current external blockers

Live deployment needs Azure subscription, tenant, region, globally valid naming prefix, authorized bootstrap principal, GitHub variables, and a private AKS network/DNS runner. Discord testing also requires TF_VAR_discord_webhook_url.

## Done means

The candidate work has been reconciled into an origin/main-based branch; static validation passes; assets are additive and credential-free; policies/workflows preserve the trust chain and PR restrictions; documentation distinguishes pending work from real evidence. Live deployment remains a separate, explicitly authorized phase.
