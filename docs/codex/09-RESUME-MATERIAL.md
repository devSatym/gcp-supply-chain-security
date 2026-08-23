# Resume Material

## One-line project summary

Built a canonical monorepo supply-chain security platform that provisions a
private GKE/GAR foundation, authenticates GitHub Actions with repository-scoped
Workload Identity Federation, signs and attests images keylessly with Cosign,
enforces digest/SBOM/provenance policy with Kyverno, deploys through Argo CD,
and detects post-admission runtime behavior with Falco eBPF.

## Resume bullets

- Designed a GitHub Actions → GCP WIF → immutable Artifact Registry pipeline;
  removed service-account JSON keys and verified keyless Cosign signatures,
  SPDX SBOMs, SLSA provenance, and Rekor evidence for a live GKE deployment.
- Implemented Kyverno `Enforce` admission controls for signatures, digest
  pinning, SBOM, provenance builder/entrypoint/source identity, and complete
  `containers`/`initContainers` coverage; demonstrated trusted admission and
  unsigned/tampered-path denial.
- Provisioned private regional GKE, VPC/NAT/firewalls, GAR, WIF, CI IAM, and a
  dedicated read-only Kyverno verifier identity with Terraform and remote GCS
  state; final Terraform plan returned no drift.
- Delivered GitOps with Argo CD and Helm, pinned the live workload to an
  immutable digest, and validated service health from inside the cluster.
- Deployed Falco modern eBPF and Falcosidekick; wrote a custom supply-chain
  runtime rule that emitted a CRITICAL event for a controlled shell in an
  admitted workload without introducing static credentials.
