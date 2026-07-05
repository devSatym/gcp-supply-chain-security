# falco

Falco DaemonSet + Falcosidekick on GKE via Helm, with modern_ebpf as the
default kernel instrumentation driver (no privileged kernel module builds
required). Ships with a base ruleset plus an optional custom rules file for
cluster-specific detections (e.g. flagging any shell exec on a cluster where
every workload is signed and scanned before admission).

## Usage

```hcl
module "falco" {
  source = "../../falco"

  project_id             = "my-gcp-project"
  cluster_name           = "prod-cluster"
  region                 = "europe-west1"

  alert_pubsub_topic_id             = module.falco_alerting.pubsub_topic_id
  falcosidekick_gsa_email           = google_service_account.falcosidekick.email
  falcosidekick_gcp_credentials_b64 = google_service_account_key.falcosidekick.private_key

  falco_helm_version = "9.1.0"

  custom_rules_yaml = <<-EOT
    - rule: Shell Spawned In Signed Workload Pod
      desc: No pod in this cluster should ever exec a shell.
      condition: spawned_process and container and proc.name in (shell_binaries)
      output: Unexpected shell spawned (pod=%k8s.pod.name ns=%k8s.ns.name)
      priority: CRITICAL
      tags: [supply-chain, shell]
  EOT
}
```

This module has no standalone `examples/` directory — it is designed to run
only against a real, already-provisioned GKE cluster (see
`environments/prod/falco.tf` for the live wiring), not as an isolated demo.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.7.0 |
| google | >= 5.30.0 |
| kubernetes | >= 2.38.0 |
| helm | >= 2.17.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | GCP project ID where the GKE cluster lives | `string` | n/a | yes |
| cluster_name | Name of the GKE cluster to deploy Falco onto | `string` | n/a | yes |
| region | Region of the GKE cluster | `string` | n/a | yes |
| namespace | Kubernetes namespace for Falco and Falcosidekick | `string` | `"falco-system"` | no |
| falco_helm_version | Version of the falcosecurity/falco Helm chart | `string` | `"4.7.4"` | no |
| falco_driver | Kernel instrumentation driver (`modern_ebpf`, `ebpf`, `kmod`) | `string` | `"modern_ebpf"` | no |
| enable_falcosidekick | Deploy Falcosidekick alert routing service | `bool` | `true` | no |
| alert_pubsub_topic_id | Pub/Sub topic ID Falcosidekick publishes alerts to | `string` | `null` | no |
| falcosidekick_gsa_email | Email of the GCP service account Falcosidekick uses to publish to Pub/Sub | `string` | n/a | yes |
| falcosidekick_gcp_credentials_b64 | Base64-encoded JSON key for the Falcosidekick GSA | `string` | n/a | yes |
| custom_rules_yaml | Optional raw YAML for custom Falco rules and macros | `string` | `""` | no |
| resources | CPU/memory requests and limits for the Falco DaemonSet | `object` | see `variables.tf` | no |
| labels | Common labels applied to Falco resources | `map(string)` | see `variables.tf` | no |

## Outputs

| Name | Description |
|------|-------------|
| namespace | Namespace Falco and Falcosidekick were deployed into |
| helm_release_status | Status of the Falco Helm release, useful for CI pipeline checks |

## Authors

Module is maintained by the Platform Team.

## License

Apache 2 Licensed. See LICENSE for full details.