# Repository Audit

Audit and implementation date: 2026-08-23
Repository: `devSatym/gcp-supply-chain-security`

## Executive result

The current canonical monorepo history passes. The application and infrastructure
components remain separated by the root/infrastructure directory boundary, and
the live GCP/GitHub/Kubernetes path now runs from the canonical repository. No
Git history repair or rewrite was performed.

Previous blocker: the master prompt referenced obsolete pre-rewrite SHAs.
Resolution: the current canonical two-parent topology was independently verified.
History repair performed: **NO**.
History rewrite performed during this implementation: **NO**.

## Canonical history gate

| Check | Result |
| --- | --- |
| Merge `6717e4491d3e8a2d0b6fd6044a673041f30d040c` exists | PASS |
| First parent `cc1fa07a617320a8efdf31bb9aa67927128bd3a0` exists and is an ancestor of `HEAD` | PASS |
| Second parent `c88320f1b2ac1995aa1d75f481e1f69d7063c2ba` exists and is an ancestor of `HEAD` | PASS |
| Merge has exactly two parents | PASS |
| Post-merge documentation commit `b90bcc75dae48231a04e2efcedc51eb70dfac89c` exists | PASS |

The old IDs `cf131149…`, `d15ce752…`, `76c26bd…`, and `3d29f6f…` were not
required and were not restored.

## Monorepo and identity findings

The active remote is `https://github.com/devSatym/gcp-supply-chain-security.git`.
Historical attribution remains in `docs/repository-merge.md` and the imported
infrastructure documentation; those references are not runtime trust values.
Active runtime identity is now the canonical repository in Argo CD, Kyverno,
Cosign/OCI metadata, GitHub Actions WIF, CODEOWNERS, Renovate, and the ruleset
Terraform configuration.

`infrastructure/` contains the imported infrastructure component. The nested
`infrastructure/.github/workflows/terraform.yml` is retained provenance material;
GitHub does not execute nested workflows. The active root workflow is
`.github/workflows/infrastructure-terraform.yml` and is scoped to
`infrastructure/**`.

The executable `infrastructure/kubernetes-addons` module installs only optional
metrics-server and ExternalDNS. It does not install Kyverno, Gatekeeper, or
cert-manager. Kyverno is therefore installed separately by Helm; Gatekeeper and
Ratify remain disabled compatibility material.

The unreferenced `k8s/manifests/` directory is retained as a legacy/reference
manifest set. The Helm chart under `k8s/helm/supply-chain-demo/` is the active
Argo CD source. The retained direct deployment now has valid `@sha256:` syntax,
but is not the active deployment path.

## Live application and trust path

- The Dockerfile uses Python 3.12 slim Trixie, removes build tooling from the
  runtime virtualenv, runs as UID/GID 10001, and carries a narrow documented
  Trivy exception only for the Debian Trixie QUIC-only CVE with no fix.
- Primary GAR repository (immutable tags):
  `europe-west1-docker.pkg.dev/valiant-house-502004-k2/supply-chain-security`.
- Cosign v2 legacy signature/attestation index repository (mutable tags):
  `europe-west1-docker.pkg.dev/valiant-house-502004-k2/supply-chain-security-attestations/supply-chain-demo`.
  The metadata repository is only an appendable index; every artifact remains
  cryptographically bound to the immutable primary digest.
- The deployed Helm digest is
  `sha256:32a90d832fdf76794fa5477e42e1fdcec28c9eb6e0deee48ad466d1f7d9fc563`.
- Kyverno 1.19.0 enforces signature, SPDX SBOM, SLSA provenance, Rekor, digest,
  signer identity, builder, entrypoint, and canonical source URI. It reads GAR
  through the repository-scoped `kyverno-verifier` GSA via GKE Workload Identity.
- Argo CD 3.5.1 reports the application `Synced` and `Healthy` from
  `k8s/helm/supply-chain-demo`.
- The unsigned GAR tag `unsigned-test` is a disposable negative-test artifact;
  it has no Cosign metadata and is denied by Kyverno.

## Live infrastructure

The approved target is project `valiant-house-502004-k2` (number
`747109416512`) in `europe-west1`. Terraform state is stored in the versioned,
uniform-access bucket `gs://valiant-house-502004-k2-gcp-supply-chain-tfstate`
under prefix `gcp-supply-chain-security/prod`.

Terraform created the private VPC/NAT/firewalls, regional GKE cluster
`prod-cluster`, node-pool service account, immutable and metadata GAR
repositories, dedicated GitHub WIF pool/provider, CI service account, and
Kyverno verifier GSA. The node pool is configured with total autoscaling bounds
1–2 `e2-standard-4` nodes; GKE autoscaled the live test cluster to one node,
which currently serves the healthy two-replica application and all controllers.

Falco 0.44.1 (chart 9.1.0) and Falcosidekick 2.32.0 are live in
`falco-system`, using modern eBPF. The custom shell rule fired at CRITICAL for a
controlled `kubectl exec` shell in the admitted workload. Pub/Sub → Cloud
Function → Discord alerting is not enabled because no Discord webhook was
provided; the Terraform guard prevents a placeholder secret or function.

## Validation classification

Personal live evidence is recorded in `docs/my-validation/`. Files in
`docs/evidence/` are historical upstream evidence and remain clearly separate.
The current validation matrix is `docs/codex/03-VALIDATION.md`; the handoff and
cleanup status are in `05-HANDOFF.md` and `07-COST-AND-CLEANUP.md`.

Static checks passed: Terraform formatting and validation, Helm lint/render,
YAML/server dry-runs, identity consistency, Kyverno JMESPath conditions, and
final Terraform no-drift plan. The canonical main deployment workflow
`32630716371` completed successfully for commit `9bf574c`, including build,
Trivy image scan, keyless signing, SBOM, provenance, and verification.

## Remaining external step

The implementation is operational for the signed-image/GitOps/admission/runtime
path. A real PR should still exercise the PR-only Semgrep/Trivy required checks
before activating the GitHub ruleset remotely. Discord alert delivery requires
the user to supply a real incoming-webhook URL; it must be placed only in the
ignored local Terraform variables and Secret Manager flow.
