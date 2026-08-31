terraform {
  # google_secret_manager_secret_version.secret_data_wo requires Terraform 1.11+.
  required_version = ">= 1.11.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.0.0, < 8.0.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4"
    }
  }
}
