# Azure workload assets

`supply-chain-demo/` is an Azure-specific Helm chart with the same application
security context, probes, service, and digest-only deployment behavior as the
GCP chart. Only the registry source changes: AKS pulls from ACR through its
kubelet managed identity, so no `imagePullSecret` or ACR admin credential is
stored in the chart.

Before the Azure Argo CD Application is created or synced, render a verified
ACR image digest into a temporary values file:

```bash
export ACR_LOGIN_SERVER='YOUR_REGISTRY.azurecr.io'
export ACR_APPLICATION_REPOSITORY='supply-chain-security/supply-chain-demo'
export IMAGE_DIGEST='sha256:REPLACE_WITH_A_DIGEST_VERIFIED_BY_AZURE-VERIFY'

envsubst < k8s/azure/supply-chain-demo/values.yaml >/tmp/supply-chain-azure-values.yaml
helm lint k8s/azure/supply-chain-demo
helm template supply-chain-demo k8s/azure/supply-chain-demo \
  --values /tmp/supply-chain-azure-values.yaml
```

The Argo CD Application consumes `values.release.yaml`, which must be
added by an owner-reviewed promotion change only after the trusted Azure main
workflow has completed build, scan, signing, attestation, verification, and
image locking. Do not sync the checked-in placeholder values: they intentionally
do not form a valid OCI image reference. `values.release.yaml.example`
documents the shape without inventing an Azure registry or digest.
