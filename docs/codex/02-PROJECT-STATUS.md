# Project Status

Last updated: 2026-08-23

| Field | Current status |
| --- | --- |
| History integrity | **PASS** — canonical merge has two parents and both are ancestors of `HEAD` |
| History repair/rewrite | **NO / NO** |
| Repository | `devSatym/gcp-supply-chain-security` |
| GCP target | `valiant-house-502004-k2` (`747109416512`), `europe-west1` |
| Terraform state | `gs://valiant-house-502004-k2-gcp-supply-chain-tfstate/gcp-supply-chain-security/prod` |
| GKE | `prod-cluster`, regional, live; autoscaling total 1–2 `e2-standard-4` nodes |
| GAR | Immutable primary repository plus mutable Cosign metadata repository |
| GitHub WIF | Dedicated pool/provider scoped to `devSatym/gcp-supply-chain-security` |
| GitHub variables | GAR, WIF, CI service account, and `COSIGN_REPOSITORY` configured |
| Kyverno | 1.19.0, policy Ready, `Enforce`, repository-scoped reader GSA via GKE WI |
| Argo CD | 3.5.1, `supply-chain-demo` `Synced/Healthy` |
| Application | 2/2 replicas healthy from signed digest `sha256:32a90d…f7d9fc563` |
| Falco | 0.44.1 modern eBPF, one DaemonSet pod on the current autoscaled node |
| Falcosidekick | 2 replicas healthy; Pub/Sub output disabled until webhook supplied |
| Latest trusted main chain | `32638968765`: all jobs passed for `27a94b0`, including final Trivy, signing, attestations, strict Verify, and SBOM/VEX |
| Final Terraform drift | PASS — `No changes` |
| Active CI audit | Complete; CI-001 and CI-002 fixed and validated on a real PR and subsequent main run |

## Completed evidence

- VPC/GKE foundation and GAR/WIF/IAM targeted Terraform applies succeeded.
- Kyverno trusted-image server dry-run passed.
- Real unsigned GAR image was denied with `no signatures found`.
- Mixed-container and unsigned-init fixtures were denied, covering initContainers.
- Test-only wrong signer identity and wrong provenance source policy denied the
  known signed image with both expected mismatch messages.
- Argo deployed the canonical Helm chart and reported `Synced/Healthy`.
- `/health` and `/info` responded from the in-cluster service.
- Falco loaded `custom-rules.yaml` and emitted a CRITICAL
  `Shell Spawned In Signed Workload Pod` event for controlled `kubectl exec`.
- PR #2 passed Detect relevant changes, Semgrep, Trivy filesystem scan, policy
  tests, and PR Image Scan. Its production artifact jobs had no GCP/WIF
  authority.
- Main run `32638968765` passed the hardened trusted chain: exact-digest
  Trivy scan, keyless signing, SPDX SBOM, SLSA provenance, and fail-closed
  signature/SBOM/provenance verification. It produced verified digest
  `sha256:a0073f8f1d73f62ab0a15634a48387e78f6f837cff80f27a5c6e3b0a5c1eb16a`;
  Helm remains deliberately pinned to the earlier verified live digest until
  a reviewed manual promotion.

## Remaining work

1. Capture the CI screenshots listed in `08-SCREENSHOT-CHECKLIST.md`.
2. Establish and approve an IaC/config-scanning baseline before adding a
   fail-closed misconfiguration gate; current Trivy configuration scanning has
   genuine GKE findings and intentionally insecure negative fixtures to scope.
3. Decide whether to activate the Terraform-defined GitHub ruleset. This is a
   branch-protection change and requires explicit approval plus a reviewed
   Terraform plan.
4. If desired, provide a real Discord webhook and enable the guarded
   Pub/Sub → Cloud Function path; do not invent a value.
5. Decide when to delete the disposable unsigned GAR artifact and whether to
   retain the live project for portfolio evidence.

## Local working-tree note

`docs/codex/03-VALIDATION.md`, `plan.md`, `docs/codex/12.md`, and the
two untracked validation screenshots are user-owned working-tree material.
They were intentionally excluded from this CI documentation update.
