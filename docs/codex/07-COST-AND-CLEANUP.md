# Cost and Cleanup

## Current cost drivers

The live cost drivers are the regional GKE control plane, the autoscaled
`e2-standard-4` node pool (currently one node, configured total range 1–2),
balanced disks, Cloud NAT, VPC flow logs, GAR storage/egress, and cluster
workload capacity. Managed Prometheus, ExternalDNS, and the Pub/Sub/Cloud
Function/Discord route are disabled. Prices and quota should be reviewed in
the GCP console before keeping the environment beyond the evidence window.

## Cleanup order

1. Preserve the final signed digest, CI logs, Argo/Kyverno/Falco transcripts,
   and screenshots until the portfolio evidence is complete.
2. Delete the disposable `unsigned-test` GAR version and any temporary test
   pods/policies after evidence review. The test policy was already removed;
   no negative test pod was admitted.
3. Remove the committed negative-test Argo Application only if it was applied
   later; it is not part of the current live Application.
4. If the cluster is no longer needed, uninstall manually installed Argo CD and
   Kyverno after removing the application and policy, then verify namespaces.
5. Only with explicit approval, run the reviewed Terraform destroy for the
   prod root. This removes GKE, network, GAR, IAM/WIF, and Falco resources.
6. Decide separately whether to retain the state bucket and final GAR digest.

Never commit or print a Discord webhook, JSON key, Terraform state, kubeconfig,
PAT, or temporary Cosign credential. Verify that no service-account keys were
created; the active CI, Kyverno, and intended Falcosidekick paths use Workload
Identity.
