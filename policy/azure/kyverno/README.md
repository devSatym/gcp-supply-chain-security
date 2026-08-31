# Azure Kyverno policy template

This directory is the AKS/ACR equivalent of the GCP Kyverno configuration. It
does not change the trust contract: a matching application image must be
digest-pinned and carry a GitHub Actions keyless Cosign signature, an SPDX SBOM
attestation, and SLSA v0.2 provenance from the Azure signing workflow on
`refs/heads/main`.

The policy intentionally contains Terraform `${...}` placeholders. They are
not valid OCI image references, so the checked-in template cannot accidentally
match a production image. The private-capable production Terraform root must
render it with `templatefile()` before it is applied; never commit a rendered
result if it includes environment-specific values.

```bash
# Called by the production Terraform root (not by a shell envsubst step):
templatefile("policy/azure/kyverno/values.yaml", {
  kyverno_client_id = "UAMI_CLIENT_ID_FROM_TERRAFORM_OUTPUT"
})

templatefile("policy/azure/kyverno/block-unsigned-images.yaml", {
  acr_login_server       = "YOUR_REGISTRY.azurecr.io"
  application_repository = "supply-chain-security/supply-chain-demo"
  cosign_repository      = "YOUR_REGISTRY.azurecr.io/supply-chain-security-attestations/supply-chain-demo"
})
```

The AKS workload-identity federation and ACR repository-reader assignment for
the Kyverno service account are provisioned by `infrastructure/azure/`; those
resources are intentionally not represented by a Kubernetes secret here.
