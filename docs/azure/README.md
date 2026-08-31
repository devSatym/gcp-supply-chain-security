# Azure implementation

This directory documents the Azure implementation added on the
`feature/azure-implementation` branch. It is intentionally separate from the
existing GCP implementation and historical GCP evidence.

The Azure architecture preserves the repository's control flow:

```text
GitHub Actions OIDC -> Azure user-assigned managed identity -> ACR
  -> Trivy -> Cosign keyless signature -> SPDX + SLSA attestations
  -> verification -> digest-pinned AKS deployment -> Kyverno enforcement
  -> Falco -> Event Hubs -> Azure Functions -> Key Vault -> Discord
```

The repository now has a single idempotent convergence entry point at
`scripts/azure/apply-once.sh`. It requires the one-time remote Blob backend and
a private-network-capable applying host; it never creates local production
state. The historical 2026-08-30 live evidence is retained, but the current
subscription must be revalidated before claiming a fresh deployment.

```bash
scripts/azure/apply-once.sh --mode core
```

Use `--mode private` only with an owner-approved private GitHub runner, because
that mode closes ACR and optional alerting service public access after probes.
The first trusted main release then creates the workload through verified
digest promotion and automatic Argo reconciliation.

- [Architecture decisions](01-architecture-decisions.md)
- [Setup and bootstrap](02-setup.md)
- [Validation and evidence checklist](03-validation-checklist.md)
