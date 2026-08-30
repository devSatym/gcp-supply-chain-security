terraform {
  required_version = ">= 1.11.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.70.0, < 5.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# This example assumes an Azure resource group and private AKS cluster already
# exist. Feed the actual AKS oidc_issuer_url output into this module.
module "supply_chain" {
  source = "../.."

  resource_group_name = "rg-supply-chain-prod"
  location            = "centralindia"
  name_prefix         = "supplychain-prod"
  acr_name            = "supplychainprodacr"
  aks_oidc_issuer_url = "https://example.oidc.prod-aks.azure.com/"

  # Set from module.aks.kubelet_identity_object_id in the Azure production
  # root to provision digest-image pull access without imagePullSecrets.
  aks_kubelet_principal_id = null

  tags = {
    environment = "prod"
    owner       = "platform-team"
    project     = "supply-chain-security"
    cost_center = "engineering"
  }
}

output "acr_login_server" {
  value = module.supply_chain.acr_login_server
}

output "application_image_repository" {
  value = module.supply_chain.application_image_repository
}

output "cosign_metadata_repository" {
  value = module.supply_chain.cosign_metadata_repository
}
