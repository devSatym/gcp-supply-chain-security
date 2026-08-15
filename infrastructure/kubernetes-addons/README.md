# kubernetes-addons

In-cluster add-ons for a GKE cluster: metrics-server and External DNS
(authenticated to Cloud DNS via Workload Identity, no static keys).

Cluster Autoscaler and load-balancer/ingress controllers are **not**
included here — GKE provides both natively (node pool `autoscaling {}` in
the `gke` module, and the built-in Ingress/Gateway controller), so no
separate add-on deployment is needed for parity with the AWS blueprint's
Cluster Autoscaler / AWS Load Balancer Controller add-ons.

## Usage

```hcl
module "kubernetes_addons" {
  source = "../../"

  project_id   = "my-gcp-project"
  cluster_name = module.gke.cluster_name

  dns_domain_filter = "example.com"

  environment   = "prod"
  owner         = "platform-team"
  project_label = "core-infrastructure"
  cost_center   = "engineering"
}
```

Requires a configured `kubernetes` and `helm` provider pointed at the GKE
cluster's endpoint/CA (see [examples/complete](./examples/complete)).

## Examples

- [Complete](./examples/complete) - Full example wiring up provider auth against a GKE cluster

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.7.0 |
| google | >= 5.30.0 |
| helm | >= 2.13.0 |
| kubernetes | >= 2.30.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | GCP project ID | `string` | n/a | yes |
| cluster_name | GKE cluster name | `string` | n/a | yes |
| enable_metrics_server | Deploy metrics-server (leave off — GKE ships its own) | `bool` | `false` | no |
| enable_external_dns | Deploy External DNS | `bool` | `true` | no |
| dns_domain_filter | Domain External DNS may manage | `string` | `""` | no |
| external_dns_policy | `sync` or `upsert-only` | `string` | `"upsert-only"` | no |
| environment | dev / staging / prod | `string` | n/a | yes |
| owner | Owner label | `string` | n/a | yes |
| project_label | Project label | `string` | n/a | yes |
| cost_center | Cost center label | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| external_dns_service_account_email | GSA email used by External DNS |
| metrics_server_release_status | Helm release status |
| external_dns_release_status | Helm release status |

## Authors

Module is maintained by the Platform Team.

## License

Apache 2 Licensed. See LICENSE for full details.
