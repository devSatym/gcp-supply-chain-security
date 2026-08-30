# Azure architecture decisions

## Preserve the GitHub/Cosign/Kyverno trust contract

The Azure implementation continues to use GitHub Actions, keyless Cosign,
SPDX and SLSA attestations, Kyverno, Argo CD, and Falco. Azure-native Notation
or Azure Policy are not substituted for this path because doing so would change
the existing signer and admission-policy semantics.

## GitHub OIDC uses a user-assigned managed identity

GitHub Actions exchanges its OIDC token for an Azure user-assigned managed
identity (UAMI). The federated credential is constrained to the canonical
repository and trusted release ref. No client secret or ACR admin account is
used. The feature branch is static-validation-only; it retains
`refs/heads/main` as the release subject unless an owner explicitly creates a
separate protected release branch and changes every related trust assertion.

## One ACR, two logical repositories

The Azure Container Registry uses the application repository
`supply-chain-security/supply-chain-demo` and the mutable Cosign metadata
repository `supply-chain-security-attestations/supply-chain-demo`. The latter
preserves the established legacy Cosign signature/attestation-index behavior.
Although ACR supports OCI referrers, current Kyverno versions require a live
AKS smoke test before native-referrer discovery can replace this conservative
compatibility path.

ACR has no direct Terraform switch equivalent to GAR's repository-wide
immutable-tags control. The release process therefore uses unique commit-SHA
tags, deploys only by digest, verifies all attestations, and then locks the
promoted application tag/manifest. The metadata repository remains writable
for Cosign indexes. See [ACR image locking](https://learn.microsoft.com/en-us/azure/container-registry/container-registry-image-lock).

## Private AKS remains private

The AKS API is private. Terraform's Helm/Kubernetes providers, `kubectl`, and
Argo administration must execute from a controlled host with VNet and private
DNS access. GitHub-hosted runners perform safe static validation but cannot be
treated as a substitute for that network path.

## Workload identities are separate

- GitHub CI: ACR repository writer only.
- AKS kubelet: ACR repository reader only.
- Kyverno: ACR repository reader for the application and metadata paths.
- Falcosidekick: Azure Event Hubs Data Sender only.
- Azure Function: Event Hubs Data Receiver, Key Vault Secrets User, and the
  minimum host-storage data-plane roles.

AKS workload identity requires both the Kubernetes ServiceAccount annotation
`azure.workload.identity/client-id` and pod label
`azure.workload.identity/use: "true"`. The Falcosidekick and Kyverno Helm
values explicitly set both forms required by their respective charts.

## Runtime alerting is optional and passwordless

Falcosidekick publishes to Event Hubs through `DefaultAzureCredential`; it
does not receive a connection string. An Azure Functions Python v2 app is
triggered by Event Hubs, reads the Discord webhook from Key Vault with its
managed identity, and posts the unchanged alert format. Terraform uses the
AzureRM write-only Key Vault secret field so the webhook does not enter state.
