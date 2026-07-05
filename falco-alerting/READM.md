# falco-alerting

Pub/Sub → Cloud Function → Discord alerting pipeline for Falco. Falcosidekick
(deployed by the `falco` module) publishes alerts to the Pub/Sub topic created
here; a Cloud Function filters by minimum priority and forwards matching
alerts to a Discord channel via incoming webhook.

## Usage

```hcl
module "falco_alerting" {
  source = "../../falco-alerting"

  project_id          = "my-gcp-project"
  region              = "europe-west1"
  discord_webhook_url = var.discord_webhook_url
  min_priority        = "notice"
}
```

This module has no standalone `examples/` directory — it is designed to run
only alongside a real Falco deployment against a live cluster (see
`environments/prod/falco-alerting.tf` for the live wiring), not as an
isolated demo.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.7.0 |
| google | >= 5.30.0 |
| archive | >= 2.8.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | GCP project ID | `string` | n/a | yes |
| region | Region for the Pub/Sub topic and Cloud Function | `string` | n/a | yes |
| topic_name | Name of the Pub/Sub topic Falcosidekick publishes to | `string` | `"falco-alerts"` | no |
| discord_webhook_url | Discord incoming webhook URL (sensitive; stored in Secret Manager) | `string` | n/a | yes |
| min_priority | Minimum Falco alert priority forwarded to Discord | `string` | `"warning"` | no |
| function_source_dir | Local path to the Cloud Function source (`main.py` + `requirements.txt`) | `string` | `null` | no |
| labels | Common labels applied to alerting resources | `map(string)` | see `variables.tf` | no |

## Outputs

| Name | Description |
|------|-------------|
| pubsub_topic_id | Full Pub/Sub topic ID — pass into the `falco` module's `alert_pubsub_topic_id` |
| function_name | Name of the deployed Cloud Function |
| function_service_account | Least-privilege service account the function runs as |

## Authors

Module is maintained by the Platform Team.

## License

Apache 2 Licensed. See LICENSE for full details.