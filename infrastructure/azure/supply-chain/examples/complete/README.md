# Complete supply-chain foundation example

This example expects a resource group and an AKS cluster with OIDC issuer and
workload identity already enabled. Replace the illustrative ACR name and AKS
OIDC issuer before running a plan. It does not use or create Azure credentials.

For a real environment root, pass the AKS kubelet identity's **principal ID**
to `aks_kubelet_principal_id`; that creates repository-scoped pull grants for
the application and Cosign metadata paths.
