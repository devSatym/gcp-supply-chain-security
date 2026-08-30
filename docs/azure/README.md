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

The private Azure foundation, admission/runtime controls, Argo CD foundation,
and AKS maintenance parity are live-validated from the private jump VM on
2026-08-30. The trusted image release, reviewed GitOps promotion, optional
Discord alerting, flow-log opt-in, and private ACR closure still require the
external inputs listed in the validation checklist.

- [Architecture decisions](01-architecture-decisions.md)
- [Setup and bootstrap](02-setup.md)
- [Validation and evidence checklist](03-validation-checklist.md)
