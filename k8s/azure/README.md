# Azure workload assets

`supply-chain-demo/` is an Azure-specific Helm chart with the same application
security context, probes, service, and digest-only deployment behavior as the
GCP chart. Only the registry source changes: AKS pulls from ACR through its
kubelet managed identity, so no `imagePullSecret` or ACR admin credential is
stored in the chart.

The Terraform Kubernetes-addons module installs the private Argo CD Application
from `argocd/supply-chain-azure-demo-app.yaml`. The base chart is intentionally
inert, so it can be installed before a release exists. The trusted main
workflow generates `values.release.yaml` only after image verification and
locking:

```bash
helm lint k8s/azure/supply-chain-demo
helm template supply-chain-demo k8s/azure/supply-chain-demo \
  --values k8s/azure/supply-chain-demo/values.release.yaml.example
```

The main-only promotion job then commits only the generated
`values.release.yaml`; Argo automatically self-heals the digest-pinned
Deployment. Never replace the generated file with a mutable tag or a guessed
digest. `values.release.yaml.example` documents the shape without inventing a
real Azure registry or release.
