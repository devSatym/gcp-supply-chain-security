# gke

Private, VPC-native, regional GKE cluster with Workload Identity, per-node-pool
least-privilege service accounts, shielded nodes, and autoscaling node pools
defined as a map (the GCP analogue of AWS EKS managed node groups).

## Usage

```hcl
module "gke" {
  source = "../../"

  project_id = "my-gcp-project"
  region     = "us-central1"

  cluster_name = "production-cluster"

  network_self_link    = module.vpc.vpc_self_link
  subnetwork_self_link = module.vpc.private_subnet_self_links["main"]
  pods_range_name      = module.vpc.private_subnet_pods_range_names["main"]
  services_range_name  = module.vpc.private_subnet_services_range_names["main"]

  node_pools = {
    main = {
      machine_type = "e2-standard-4"
      min_size     = 1
      max_size     = 10
      desired_size = 3
    }
  }

  environment   = "prod"
  owner         = "platform-team"
  project_label = "core-infrastructure"
  cost_center   = "engineering"
}
```

## Examples

- [Complete](./examples/complete) - Full example with all options, wired to the vpc module

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.7.0 |
| google | >= 5.30.0 |
| google-beta | >= 5.30.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | GCP project ID | `string` | n/a | yes |
| region | GCP region | `string` | n/a | yes |
| regional | Regional (HA) vs zonal cluster | `bool` | `true` | no |
| cluster_name | Name of the GKE cluster | `string` | n/a | yes |
| cluster_version | Master version or "latest" | `string` | `"latest"` | no |
| release_channel | RAPID / REGULAR / STABLE | `string` | `"REGULAR"` | no |
| network_self_link | VPC self_link | `string` | n/a | yes |
| subnetwork_self_link | Subnet self_link for nodes | `string` | n/a | yes |
| pods_range_name | Secondary range name for pods | `string` | n/a | yes |
| services_range_name | Secondary range name for services | `string` | n/a | yes |
| enable_private_endpoint | Disable public master endpoint | `bool` | `false` | no |
| master_ipv4_cidr_block | CIDR for the GKE master | `string` | `"172.16.0.0/28"` | no |
| master_authorized_networks | CIDRs allowed to reach the master | `list(object)` | `[]` | no |
| node_pools | Map of node pool configs; sizes are total nodes across the pool | `map(object)` | n/a | yes |
| node_pool_roles | IAM roles granted to node pool SAs | `list(string)` | see variables.tf | no |
| environment | dev / staging / prod | `string` | n/a | yes |
| owner | Owner label | `string` | n/a | yes |
| project_label | Project label | `string` | n/a | yes |
| cost_center | Cost center label | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | GKE cluster ID |
| cluster_endpoint | Master endpoint IP (sensitive) |
| cluster_ca_certificate | Cluster CA cert (sensitive) |
| workload_identity_pool | `PROJECT_ID.svc.id.goog` |
| node_pool_names | Map of node pool names |
| node_pool_service_accounts | Map of node pool SA emails |
| get_credentials_command | Ready-to-run `gcloud` credentials command |

## Authors

Module is maintained by the Platform Team.

## License

Apache 2 Licensed. See LICENSE for full details.
