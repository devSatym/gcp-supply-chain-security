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
- Deploy run `32630716371` succeeded for `9bf574c`, including Trivy, keyless
  signing, SPDX SBOM, SLSA provenance, and verification.
- The Helm chart deploys digest
  `sha256:32a90d832fdf76794fa5477e42e1fdcec9eb6e0deee48ad466d1f7d9fc563`.
- Argo CD application `supply-chain-demo` is `Synced/Healthy`; two replicas are
  responding to `/health` and `/info`.
- Kyverno policy is `Ready` and `Enforce`; the real unsigned image, mixed
  container, unsigned initContainer, wrong signer, and wrong provenance source
  fixtures are denied.
- Falco custom rule loaded and emitted a CRITICAL event for a controlled shell.

## Intentionally pending

- PR-only Semgrep/Trivy checks have not yet been captured on a real review
  branch. Activate the remote GitHub ruleset only after those contexts are
  observed and satisfiable.
- Pub/Sub → Cloud Function → Discord is disabled because a real Discord webhook
  was not provided. If enabled, put it only in ignored local Terraform input;
  never commit or print it.
- The unsigned test image remains in GAR for evidence. Delete it only after the
  user decides evidence is complete.

## Fresh-session checks

```bash
git status --short
git log -1 --oneline
kubectl get nodes
kubectl get application -n argocd supply-chain-demo
kubectl get clusterpolicy block-unsigned-images
terraform -chdir=infrastructure/environments/prod plan -input=false
```

Do not stage or modify the untracked user-owned `plan.md`. Do not run history
repair commands or `terraform destroy` without a separately reviewed request.
