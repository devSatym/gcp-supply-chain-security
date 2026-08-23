# Handoff

## Current state

The canonical monorepo is operational through build, signing, verification,
GitOps deployment, Kyverno admission, and Falco runtime detection. The live
target is project `valiant-house-502004-k2` in `europe-west1`.

## What is verified

- Canonical merge topology passes; no history repair or rewrite occurred.
- Terraform foundation, delivery IAM/WIF, Kyverno reader identity, and Falco
  targeted applies succeeded; final Terraform plan reports no changes.
- GitHub variables point to the target GAR, WIF provider, CI service account, and
  separate Cosign metadata repository.
- PR #2 (`ci: harden trusted supply-chain verification`) passed relevant
  change detection, Semgrep, Trivy filesystem scanning, policy tests, and a
  local Trivy image scan. It received no privileged production authority.
- Main Deploy run `32638968765` for merge commit `27a94b0` passed
  Build and Push, immutable-digest Trivy scan, keyless signing, SPDX SBOM,
  SLSA provenance, and hardened Verify checks. Its verified output digest is
  `sha256:a0073f8f1d73f62ab0a15634a48387e78f6f837cff80f27a5c6e3b0a5c1eb16a`;
  it has not been manually promoted into Helm desired state.
- The Helm chart deploys digest
  `sha256:32a90d832fdf76794fa5477e42e1fdcec28c9eb6e0deee48ad466d1f7d9fc563`.
- Argo CD application `supply-chain-demo` is `Synced/Healthy`; two replicas are
  responding to `/health` and `/info`.
- Kyverno policy is `Ready` and `Enforce`; the real unsigned image, mixed
  container, unsigned initContainer, wrong signer, and wrong provenance source
  fixtures are denied.
- Falco custom rule loaded and emitted a CRITICAL event for a controlled shell.

## Remaining intentional or approval-gated work

- The PR-only Semgrep/Trivy/policy/image gates have now been captured.
  GitHub ruleset activation is still intentionally pending explicit approval
  and a reviewed Terraform plan.
- An IaC/misconfiguration scanner is not yet an active blocking gate. Establish
  an owned baseline first: current scans report GKE findings and intentionally
  insecure negative fixtures, while the active older Trivy version has an
  observed misconfiguration-scan failure on the whole repository.
- Pub/Sub → Cloud Function → Discord is disabled because a real Discord webhook
  was not provided. If enabled, put it only in ignored local Terraform input;
  never commit or print it.
- The unsigned test image remains in GAR for evidence. Delete it only after the
  user decides evidence is complete.
- `docs/codex/03-VALIDATION.md` currently contains user-owned uncommitted
  capture data. Reconcile it deliberately before replacing or reformatting it.

## Fresh-session checks

```bash
git status --short
git log -1 --oneline
kubectl get nodes
kubectl get application -n argocd supply-chain-demo
kubectl get clusterpolicy block-unsigned-images
terraform -chdir=infrastructure/environments/prod plan -input=false
gh run view 32638968765 --repo devSatym/gcp-supply-chain-security
```

Do not stage or modify the user-owned working-tree files listed in
`02-PROJECT-STATUS.md`. Do not run history repair commands or `terraform
destroy` without a separately reviewed request.
