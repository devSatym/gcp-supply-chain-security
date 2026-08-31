# Azure Kubernetes add-ons

This module installs Kyverno with AKS Workload Identity, applies the Azure ACR
policy that verifies the existing Cosign keyless signature, SPDX SBOM, and SLSA
provenance contract, and installs a pinned private Argo CD foundation. It does
not create an ACR pull secret: Kyverno uses its dedicated managed identity and
Kyverno's Azure registry credential helper.

The calling provider must be able to reach private AKS. Kyverno and its CRDs
are installed by `helm_release.kyverno`; the rendered `ClusterPolicy` is then
installed by the dependent local `kyverno-policy` Helm release in the same
Terraform apply. This avoids Kubernetes-provider discovery of a CRD before the
first Helm release has created it.

`install_policy = false` disables the dependent policy release, but is not
needed for a new cluster. An optional metrics-server is retained for parity
but remains disabled because AKS monitoring is normally served by Azure
Monitor/managed metrics.

Argo CD is enabled by the install_argocd input and uses argocd-values.yaml:
its server is ClusterIP-only, ingress and Dex are disabled, and the controller
replicas are sized for the constrained demo cluster. The module then packages
the single reviewed `argocd/supply-chain-azure-demo-app.yaml` manifest as a
local Helm release after Argo's CRDs are installed. The Application tolerates
an absent `values.release.yaml`, automatically prunes and self-heals once the
trusted main promotion job commits the verified digest, and never exposes a
public Argo service.
