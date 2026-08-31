terraform {
  # The environment consumes write-only Key Vault values through the alerting
  # module and ABAC registry permissions through azurerm, so keep the same
  # Terraform and provider baseline as the child modules.
  required_version = ">= 1.11.0"

  # Backend values are supplied at init time from the bootstrap-state outputs.
  # Keeping the block empty prevents live identifiers from entering source
  # control while making remote state explicit.
  backend "azurerm" {}

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.70.0, < 5.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.13.0, < 3.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.30.0, < 3.2.2"
    }
  }
}

provider "azurerm" {
  features {}
}

# The cluster API is private. Providers must run from a host with VNet and
# private-DNS access to the cluster; kubelogin performs Azure RBAC user or
# managed-identity authentication, so no kubeconfig secret is stored anywhere.
# 6dae42f8-4368-4678-94ff-3960e28e3630 is the public, well-known AKS server
# application ID used by every AKS cluster, not an environment identifier.
locals {
  aks_oidc_server_id = "6dae42f8-4368-4678-94ff-3960e28e3630"
}

provider "kubernetes" {
  host                   = module.aks.host
  cluster_ca_certificate = base64decode(module.aks.cluster_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "kubelogin"
    args        = ["get-token", "--login", "azurecli", "--server-id", local.aks_oidc_server_id]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.aks.host
    cluster_ca_certificate = base64decode(module.aks.cluster_ca_certificate)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "kubelogin"
      args        = ["get-token", "--login", "azurecli", "--server-id", local.aks_oidc_server_id]
    }
  }
}
