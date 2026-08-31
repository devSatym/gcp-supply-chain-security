# Azure DevSecOps controls matrix

| Control | Implementation | Evidence |
|---|---|---|
| Secret prevention | GitHub secret scanning/push protection plus Gitleaks full-history gate | GitHub Security tab and `DevSecOps Security Gates` |
| Code and dependency security | CodeQL, Semgrep, pip-audit, Trivy, license inventory | SARIF and workflow artifacts |
| IaC and workflow safety | Checkov, OPA Conftest, actionlint, zizmor, Azure static validation | PR workflow logs |
| Azure authentication | GitHub OIDC federated credentials bound to immutable trusted-main subject | Terraform state and Azure identity resources |
| State protection | Blob versioning/soft delete, Entra data-plane access, shared keys disabled, deny-by-default firewall | `bootstrap-state` resources |
| Cluster isolation | Private AKS API, private runner, no public runner IP, restricted namespace PSA | AKS properties and rendered chart |
| Workload hardening | Digest-only images, non-root, RuntimeDefault seccomp, read-only root, no token mount, PDB, NetworkPolicy | Helm render and Kyverno policy |
| Artifact integrity | Cosign keyless signature, SPDX SBOM, SLSA provenance, independent verification, manifest lock | Azure deploy workflow and ACR manifest properties |
| Admission and runtime | Kyverno signature/attestation policy plus restricted workload policy; Falco rules | Kubernetes policies and Falco events |
| DAST and drift | Private ZAP baseline and scheduled read-only Terraform plan | workflow artifacts and summaries |

Paid Microsoft Defender for Cloud and Microsoft Sentinel are deliberately not
enabled by default. Enable them only after the owner accepts their subscription
cost and retention impact; this baseline still collects platform-level logs and
enforces the controls above without silently creating paid services.

## Checkov exception register

Checkov runs from a pinned current container and fails the PR on every rule not
listed in [`.checkov.yml`](../../.checkov.yml). The following exceptions are
reviewed controls, not ignored findings; remove them when their stated
prerequisite is available.

| Rule group | Reason and compensating control | Removal condition |
|---|---|---|
| `CKV_AZURE_116`, `117`, `168`, `170`, `172`, `226`, `227`, `232` | AKS is private, Entra Azure RBAC-only, monitored, and protected by Kyverno/Falco. The remaining checks require a paid SLA, a customer-managed disk encryption set, a supported ephemeral-disk VM size, or a dedicated system/user-node split that must be supplied by the owner. | Owner approves the availability and CMK design and the required AKS node-pool migration is complete. |
| `CKV_AZURE_33`, `206`, `CKV2_AZURE_1`, `21` | AzureRM v4 manages Storage logging as separate resources; storage uses TLS 1.2, Entra-only data access, soft delete, versioning, infrastructure encryption, and diagnostic settings. Geo-replication and CMKs remain explicit cost/key-management choices. | AzureRM/Checkov correlates the split logging resource, and the owner supplies a CMK/replication requirement. |
| `CKV_AZURE_36`, `59` | The state firewall deliberately does **not** grant every trusted Microsoft service a bypass. It accepts only the explicit runner subnet and owner break-glass IP while private access is introduced; the temporary public route remains deny-by-default. | The private runner proves Blob DNS/HTTPS through the state private endpoint and public state access is disabled. |
| `CKV_AZURE_212`, `221`, `225` | Discord alerting is opt-in and uses an Azure Functions Consumption plan. The function is not created without the owner-provided webhook; private endpoints are created and tested before its public path is closed. | Owner enables alerting and approves a dedicated private/zone-redundant plan. |
| `CKV_AZURE_50` | The private runner has no public IP and uses cloud-init, not a VM extension. | Checkov correctly distinguishes cloud-init from VM extensions. |
| `CKV_AZURE_139`, `164`, `165`, `166`, `233` | ACR is single-region Premium and uses repository-scoped OIDC, Cosign keyless signatures, SBOM/provenance, Kyverno verification, and digest-only deployment. Public data access is a staged bootstrap setting until the private runner proves DNS/HTTPS to both ACR private endpoints. | Private-endpoint probes pass and public ACR access is disabled; add geo-replication or Defender only with owner cost approval. |
| `CKV2_AZURE_31`, `33`, `40`, `41` | AKS API-server VNet integration requires a dedicated delegated subnet. Optional Network Watcher flow logs use the documented Azure service integration and are never reused for workloads. | Azure supports the required NSG/Private Link path without breaking the delegated API subnet or flow-log ingestion. |
