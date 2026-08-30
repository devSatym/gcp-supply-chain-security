terraform {
  # Write-only resource arguments keep the Discord webhook out of plans/state.
  required_version = ">= 1.11.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.0.0, < 8.0.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.30.0, < 8.0.0"
    }
    helm = {
      source = "hashicorp/helm"
      # The provider's inline kubernetes {} configuration used below is v2-only.
      version = ">= 2.13.0, < 3.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.30.0, < 3.0.0"
    }
  }

  # Backend identity is deliberately supplied at `terraform init` time. The
  # imported upstream bucket is not part of this canonical monorepo.
  backend "gcs" {}
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# The kubernetes/helm providers need a live cluster to talk to, so they're
# configured using data sources that read the cluster this same root module
# creates. On a brand new project this means: first `terraform apply` with
# -target on vpc/gke, then a second plain apply to bring up the addons —
# or just apply twice, which Terraform handles gracefully since the data
# sources simply won't resolve until the cluster exists.
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${module.gke.cluster_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${module.gke.cluster_endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
  }
}
