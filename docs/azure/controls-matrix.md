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
