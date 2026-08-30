terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.44.0, < 5.0.0"
    }
  }
}

# bootstrap-state is intentionally a root configuration, rather than a
# reusable child module. Azure AD data-plane authentication keeps storage keys
# disabled while Terraform creates and uses the state container.
provider "azurerm" {
  features {}

  storage_use_azuread = true
}
