# Resource Inventory

No deployment resource has been created. The configured GCP project candidate is known, and the table records intended Terraform-managed resources; `Created?` means verified in this project, not merely declared in code.

| Resource | Name / region | Purpose | Created? | Cost relevance | Management / destroy mechanism |
| --- | --- | --- | --- | --- | --- |
| GCP project | Candidate `valiant-house-502004-k2` / number `747109416512` | Deployment boundary | No — candidate only | Billing boundary | User must accept before apply |
| GCS state bucket | Existing candidates: `valiant-house-502004-k2-tf-state` (ASIA-SOUTH1) and `valiant-house-502004-k2-tfstate` (US-CENTRAL1); no selection made | Versioned Terraform state | No | Storage/operations | User chooses reuse versus a dedicated bucket/location; do not destroy casually |
| VPC / subnets / router / NAT | Derived from `name` and `environment` | Private GKE networking and egress | No | NAT, logs, egress | Terraform root; `terraform destroy` only with approval |
| GKE cluster / node pools | `prod-cluster` example / selected region | Kubernetes runtime | No | Control plane, nodes, disks, logs | Terraform root; destroy only with approval |
| GAR repository | `supply-chain-security` in chosen region | Immutable image and attestations | No | Storage / egress | Declared in Terraform prod root |
| CI service account / WIF pool/provider | `supply-chain-ci` / `supply-chain-github-pool` / `github-provider` | GitHub OIDC to GAR | No | No material direct cost | Declared in Terraform prod root; dedicated to canonical repo and separate from existing `github-pool` federation |
| Kyverno / Argo CD | `kyverno` / `argocd` namespaces | Admission and GitOps | No | Cluster capacity | Helm, documented uninstall procedure |
| Falco / Falcosidekick | `falco-system` | Runtime detection / Pub/Sub publication | No | Cluster capacity | Terraform Helm release |
| Pub/Sub topic | `falco-alerts` default | Alert transport | No | Message volume | Terraform module |
| Cloud Function v2 / source bucket | `falco-discord-notifier` / project-derived bucket | Discord notification | No | Invocations, build/storage | Terraform module |
| Discord webhook secret | Secret Manager `falco-discord-webhook-url` | Notification destination | No | Secret versions | Terraform creates secret; value stays in ignored tfvars |

The retained Ratify JSON-key compatibility code is guarded by `enable_legacy_ratify = false`; it is excluded from the intended final design. Falcosidekick no longer declares a JSON service-account key and uses GKE Workload Identity instead.
