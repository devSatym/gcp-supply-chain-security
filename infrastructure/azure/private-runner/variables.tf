variable "resource_group_name" {
  description = "Resource group containing the private runner VM."
  type        = string
}

variable "location" {
  description = "Azure region for the private runner VM."
  type        = string
}

variable "subnet_id" {
  description = "ID of the isolated private runner subnet."
  type        = string
}

variable "name_prefix" {
  description = "Prefix used for the runner VM and network interface names."
  type        = string
}

variable "admin_ssh_public_key" {
  description = "Ephemeral operator public key required by the Azure Linux VM API. It is never used for network access because the runner has no public IP and the NSG denies SSH."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^ssh-(ed25519|rsa) ", var.admin_ssh_public_key))
    error_message = "admin_ssh_public_key must be a valid OpenSSH ed25519 or RSA public key."
  }
}

variable "vm_size" {
  description = "VM size for the private build, scan, signing, and Terraform runner."
  type        = string
  default     = "Standard_D2s_v5"
}

variable "admin_username" {
  description = "Linux administrator account required by the Azure VM API. The runner itself uses a separate unprivileged account."
  type        = string
  default     = "azureadmin"
}

variable "tags" {
  description = "Resource tags applied to the private runner resources."
  type        = map(string)
  default     = {}
}
