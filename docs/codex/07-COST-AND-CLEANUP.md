# Cost and Cleanup

## Cost review before apply

The primary cost drivers are a regional GKE control plane, two `e2-standard-4` example nodes with 100 GB balanced disks, Cloud NAT, VPC flow logs, Artifact Registry storage/egress, Cloud Functions v2 builds/invocations, Pub/Sub messages, Secret Manager versions, and source-bucket storage. Managed Prometheus, ExternalDNS, and runtime alerting are disabled by default. Exact prices depend on the accepted region and current GCP pricing and must be reviewed immediately before apply.

No resource was created during the audit.

## Candidate-project readiness snapshot

Read-only inspection of configured candidate `valiant-house-502004-k2` on
2026-08-23 found it ACTIVE with billing enabled and no GKE cluster or Artifact
Registry repository in `europe-west1`. Regional quota is currently 32 general
CPUs, 8 E2 CPUs, 2,048 GB disks, and 4 in-use addresses, all with zero usage.
The approved two-node `e2-standard-4` pool consumes all eight E2 CPUs, leaving
no E2 autoscaling headroom. The GKE module now treats configured node-pool
sizes as totals and distributes initial nodes across the selected zones, rather
than interpreting the approved two nodes as two nodes per zone. Do not increase
the pool beyond two nodes without a quota/sizing review.

## Post-validation cleanup order

1. Keep the final trusted GAR digest and personal evidence until the user decides otherwise.
2. Delete disposable unsigned/negative-test images and workloads only after evidence is recorded.
3. Remove negative-test Argo Application resources if they were created.
4. If uninstalling manually installed Helm releases, remove Argo CD and Kyverno only after applications/policies are no longer needed.
5. Use Terraform to remove Terraform-managed infrastructure only after explicit user approval for `terraform destroy`.
6. Verify that no static service-account keys were created. The retained Ratify compatibility path is disabled and is not part of cleanup for the final design.
7. Decide separately whether to retain the GCS state bucket and GAR evidence artifact.

Never run `terraform destroy` or delete final evidence artifacts without explicit user approval. Do not store Discord webhooks, JSON keys, state, kubeconfig, tokens, or temporary Cosign material in Git.
