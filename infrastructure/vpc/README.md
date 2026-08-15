# vpc

Custom-mode GCP VPC with private subnets (carrying secondary IP ranges for
GKE pods/services), optional public subnets, Cloud Router + Cloud NAT for
private-node egress, an IAP-scoped SSH firewall rule, and VPC Flow Logs.

## Usage

```hcl
module "vpc" {
  source = "../../"

  project_id  = "my-gcp-project"
  region      = "us-central1"
  name        = "core"
  environment = "prod"

  owner         = "platform-team"
  project_label = "core-infrastructure"
  cost_center   = "engineering"

  private_subnets = {
    main = {
      cidr_block          = "10.0.0.0/20"
      pods_cidr_block     = "10.4.0.0/14"
      services_cidr_block = "10.8.0.0/20"
    }
  }

  public_subnets = {
    main = {
      cidr_block = "10.0.16.0/24"
    }
  }
}
```

## Examples

- [Complete](./examples/complete) - Full example with all options

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.7.0 |
| google | >= 5.30.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | GCP project ID | `string` | n/a | yes |
| region | GCP region | `string` | n/a | yes |
| name | Base resource name prefix | `string` | n/a | yes |
| environment | dev / staging / prod | `string` | n/a | yes |
| owner | Owner label | `string` | n/a | yes |
| project_label | Project label | `string` | n/a | yes |
| cost_center | Cost center label | `string` | n/a | yes |
| private_subnets | Map of private subnets w/ pod & service secondary ranges | `map(object)` | n/a | yes |
| public_subnets | Map of public subnets | `map(object)` | `{}` | no |
| enable_flow_logs | Enable VPC Flow Logs | `bool` | `true` | no |
| enable_iap_ssh | Allow SSH via IAP range | `bool` | `true` | no |
| labels | Additional labels | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | VPC network ID |
| vpc_self_link | VPC self_link (consumed by the gke module) |
| private_subnet_self_links | Map of private subnet self_links |
| private_subnet_pods_range_names | Map of pods secondary range names |
| private_subnet_services_range_names | Map of services secondary range names |
| router_name | Cloud Router name |
| nat_name | Cloud NAT name |

## Authors

Module is maintained by the Platform Team.

## License

Apache 2 Licensed. See LICENSE for full details.
