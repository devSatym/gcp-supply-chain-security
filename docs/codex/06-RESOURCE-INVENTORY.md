# Resource Inventory

No live-resource inventory has been confirmed. The table records intended Terraform-managed resources only; `Created?` means verified in this project, not merely declared in code.

| Resource | Name / region | Purpose | Created? | Cost relevance | Management / destroy mechanism |
| --- | --- | --- | --- | --- | --- |
| GCP project | To be confirmed | Deployment boundary | No | Billing boundary | User-selected |
| GCS state bucket | To be selected | Versioned Terraform state | No | Storage/operations | Bootstrap + Terraform backend; do not destroy casually |
| VPC / subnets / router / NAT | Derived from `name` and `environment` | Private GKE networking and egress | No | NAT, logs, egress | Terraform root; `terraform destroy` only with approval |
| GKE cluster / node pools | `prod-cluster` example / selected region | Kubernetes runtime | No | Control plane, nodes, disks, logs | Terraform root; destroy only with approval |
| GAR repository | Intended `supply-chain-security` | Immutable image and attestations | No | Storage / egress | To be added to Terraform |
| CI service account / WIF pool/provider | Names to be selected | GitHub OIDC to GAR | No | No material direct cost | To be added to Terraform |
| Kyverno / Argo CD | `kyverno` / `argocd` namespaces | Admission and GitOps | No | Cluster capacity | Helm, documented uninstall procedure |
| Falco / Falcosidekick | `falco-system` | Runtime detection / Pub/Sub publication | No | Cluster capacity | Terraform Helm release |
| Pub/Sub topic | `falco-alerts` default | Alert transport | No | Message volume | Terraform module |
| Cloud Function v2 / source bucket | `falco-discord-notifier` / project-derived bucket | Discord notification | No | Invocations, build/storage | Terraform module |
| Discord webhook secret | Secret Manager `falco-discord-webhook-url` | Notification destination | No | Secret versions | Terraform creates secret; value stays in ignored tfvars |

The current infrastructure code also declares Ratify and Falcosidekick JSON service-account keys. They are excluded from the intended final design and must not be created for it unless a future documented compatibility test proves GKE Workload Identity cannot work.
