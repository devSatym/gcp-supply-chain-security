# Resource Inventory

Verified live resources in project `valiant-house-502004-k2`, region
`europe-west1`:

| Resource | Name / identity | Purpose | Management |
| --- | --- | --- | --- |
| Terraform state | `gs://valiant-house-502004-k2-gcp-supply-chain-tfstate`, prefix `gcp-supply-chain-security/prod` | Versioned remote state | Terraform backend |
| VPC/network | `core-prod-vpc`, private subnet/ranges, router/NAT/firewalls | Private GKE networking and egress | Terraform prod root |
| GKE | `prod-cluster`, regional | Kubernetes runtime | Terraform prod root |
| Node pool | `main`, `e2-standard-4`, autoscaling total 1–2 | Workload capacity | Terraform/GKE autoscaler |
| Primary GAR | `supply-chain-security` | Immutable application image tags | Terraform/GitHub Actions |
| Cosign GAR | `supply-chain-security-attestations` | Mutable legacy Cosign indexes | Terraform/GitHub Actions/Kyverno reader |
| CI GSA | `supply-chain-ci@valiant-house-502004-k2.iam.gserviceaccount.com` | GitHub WIF image push/sign/verify | Terraform |
| GitHub WIF | `supply-chain-github-pool/github-provider` | Canonical repository OIDC exchange | Terraform |
| Kyverno GSA | `kyverno-verifier@valiant-house-502004-k2.iam.gserviceaccount.com` | Read-only GAR verification | Terraform + KSA annotation |
| Kyverno | namespace `kyverno`, chart 3.9.0 / app 1.19.0 | Enforced signature/SBOM/provenance admission | Helm |
| Argo CD | namespace `argocd`, chart 10.3.3 / app 3.5.1 | GitOps reconciliation | Helm + committed Application |
| Application | namespace `default`, `supply-chain-demo` | Two-replica signed workload | Argo CD Helm chart |
| Falco | namespace `falco-system`, chart 9.1.0 / app 0.44.1 | Runtime eBPF detection | Terraform Helm release |
| Falcosidekick | two replicas in `falco-system`, app 2.32.0 | Alert routing component | Terraform Helm release |
| Unsigned test image | GAR tag `unsigned-test`, digest `sha256:18549c45…12472ca17` | Disposable negative admission test | Delete after evidence review |

Not created: Pub/Sub topic, Cloud Function, Secret Manager webhook secret, and
Discord route. Those are conditional on `enable_runtime_alerting=true` and a
real webhook URL. The retained Ratify JSON-key resources remain guarded by
`enable_legacy_ratify=false` and were not created.
