module "vpc" {
  source = "../../"

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

  public_subnets = {
    main = {
      cidr_block = "10.0.16.0/24"
    }
  }

  enable_flow_logs = true
  enable_iap_ssh   = true

  labels = {
    team = "platform"
  }
}
