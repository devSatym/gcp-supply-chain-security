module "vpc" {
  source = "../../../vpc"

  project_id  = var.project_id
  region      = var.region
  name        = "core"
  environment = "dev"

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
}

module "gke" {
  source = "../../"

  project_id = var.project_id
  region     = var.region

  cluster_name = "dev-cluster"

  network_self_link    = module.vpc.vpc_self_link
  subnetwork_self_link = module.vpc.private_subnet_self_links["main"]
  pods_range_name      = module.vpc.private_subnet_pods_range_names["main"]
  services_range_name  = module.vpc.private_subnet_services_range_names["main"]

  node_pools = {
    main = {
      machine_type = "e2-standard-4"
      min_size     = 1
      max_size     = 5
      desired_size = 2
    }
  }

  environment   = "dev"
  owner         = "platform-team"
  project_label = "core-infrastructure"
  cost_center   = "engineering"
}
