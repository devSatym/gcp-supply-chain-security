terraform {
  # The Azure implementation uses write-only Key Vault values in a later
  # module, so keep every Azure module on the same Terraform baseline.
  required_version = ">= 1.11.0"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # AbacRepositoryPermissions is supported by this provider line. Keep the
      # next major out until the Azure implementation has been compatibility
      # tested as a whole.
      version = ">= 4.70.0, < 5.0.0"
    }
  }
}
