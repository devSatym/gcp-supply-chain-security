# -----------------------------------------------------------------------------
# Root module — prod environment
# Wires vpc -> gke -> kubernetes-addons together in the correct order.
# -----------------------------------------------------------------------------

module "vpc" {
  source = "../../vpc"

  project_id  = var.project_id
  region      = var.region
  name        = var.name
  environment = var.environment

  owner         = var.owner
  project_label = var.project_label
  cost_center   = var.cost_center

  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_flow_logs = true
  enable_iap_ssh   = true
}

module "gke" {
  source = "../../gke"

  project_id = var.project_id
  region     = var.region
  regional   = true

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  release_channel = var.release_channel
  node_locations  = var.node_locations

  network_self_link    = module.vpc.vpc_self_link
  subnetwork_self_link = module.vpc.private_subnet_self_links[var.primary_subnet_key]
  pods_range_name      = module.vpc.private_subnet_pods_range_names[var.primary_subnet_key]
  services_range_name  = module.vpc.private_subnet_services_range_names[var.primary_subnet_key]

  master_authorized_networks = var.master_authorized_networks

  node_pools = var.node_pools

  environment   = var.environment
  owner         = var.owner
  project_label = var.project_label
  cost_center   = var.cost_center
}

module "kubernetes_addons" {
  source = "../../kubernetes-addons"

  project_id   = var.project_id
  cluster_name = module.gke.cluster_name

  dns_domain_filter = var.dns_domain_filter

  enable_metrics_server = var.enable_metrics_server

  environment   = var.environment
  owner         = var.owner
  project_label = var.project_label
  cost_center   = var.cost_center

  depends_on = [module.gke]
}
