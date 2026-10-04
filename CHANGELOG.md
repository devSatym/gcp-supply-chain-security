# Changelog

Release notes distinguish source/configuration changes from observed live
deployment. Versioned releases are Azure source snapshots; the immutable
`final-gcp-commit` tag preserves the earlier GCP baseline.

## Unreleased

- Align GitHub description and topics with the active Azure implementation.
- Add contribution and security guidance, structured issue forms, a pull
  request template, and categorized release notes.
- Document repository metadata, history/tag protections, dependency alerts,
  private vulnerability reporting, and Actions SHA enforcement.
- Clarify upstream licensing before publishing a repository-wide Apache 2.0
  grant.

## Initial Azure preview

The first Azure preview covers the current reference implementation:

- Terraform modules for networking, private AKS, ACR, managed identities,
  remote state, private runner, monitoring, and Kubernetes add-ons.
- Trusted-main build, digest scan, keyless signing, SPDX SBOM, custom SLSA
  v0.2 provenance, independent verification, and manifest locking.
- Digest-pinned Argo CD desired state, Kyverno admission policies, restricted
  workload configuration, and Falco runtime detection.
- Non-privileged PR security checks, local contract tests, private DAST, and
  scheduled read-only Terraform drift detection.
- Optional managed-identity alert delivery through Event Hubs, Azure Functions,
  Key Vault, and Discord.

The preview is a source baseline. A current successful Azure end-to-end
release, authenticated Git promotion, AKS admission rejection tests, private
service closure, and optional external alert delivery require live validation.
