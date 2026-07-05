data "google_client_config" "default" {}

data "google_container_cluster" "target" {
  name     = var.cluster_name
  project  = var.project_id
  location = var.region
}

provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.target.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.target.master_auth[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes = {
    host                   = "https://${data.google_container_cluster.target.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.target.master_auth[0].cluster_ca_certificate)
  }
}

module "kubernetes_addons" {
  source = "../../"

  project_id   = var.project_id
  cluster_name = var.cluster_name

  dns_domain_filter = "example.com"

  environment   = "dev"
  owner         = "platform-team"
  project_label = "core-infrastructure"
  cost_center   = "engineering"
}
