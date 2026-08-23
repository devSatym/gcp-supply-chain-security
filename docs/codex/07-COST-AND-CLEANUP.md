# Cost and Cleanup

## Cost review before apply

The primary cost drivers are a regional GKE control plane, two `e2-standard-4` example nodes with 100 GB balanced disks, Cloud NAT, VPC flow logs, managed Prometheus, Artifact Registry storage/egress, Cloud Functions v2 builds/invocations, Pub/Sub messages, Secret Manager versions, and source-bucket storage. Exact prices depend on the chosen region and current GCP pricing and must be reviewed immediately before apply.

No resource was created during the audit.

## Post-validation cleanup order

1. Keep the final trusted GAR digest and personal evidence until the user decides otherwise.
2. Delete disposable unsigned/negative-test images and workloads only after evidence is recorded.
3. Remove negative-test Argo Application resources if they were created.
4. If uninstalling manually installed Helm releases, remove Argo CD and Kyverno only after applications/policies are no longer needed.
5. Use Terraform to remove Terraform-managed infrastructure only after explicit user approval for `terraform destroy`.
6. Verify deletion or revocation of any temporary service-account key if a documented compatibility exception was ever required.
7. Decide separately whether to retain the GCS state bucket and GAR evidence artifact.

Never run `terraform destroy` or delete final evidence artifacts without explicit user approval. Do not store Discord webhooks, JSON keys, state, kubeconfig, tokens, or temporary Cosign material in Git.
