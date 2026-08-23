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
| Latest deploy run | `32630716371`, all jobs successful for `9bf574c` |
| Final Terraform drift | PASS — `No changes` |
| Working tree | Only user-owned untracked `plan.md`; no repository changes pending |

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

## Remaining work

1. Capture screenshots/command transcripts into `docs/my-validation/`.
2. Run PR-only Semgrep/Trivy checks on a real review branch before activating
   the remote GitHub ruleset.
3. If desired, provide a real Discord webhook and enable the guarded
   Pub/Sub → Cloud Function path; do not invent a value.
4. Decide when to delete the disposable unsigned GAR artifact and whether to
   retain the live project for portfolio evidence.
