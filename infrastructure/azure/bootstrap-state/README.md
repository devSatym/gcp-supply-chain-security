# Azure Terraform state bootstrap

This directory is a standalone, one-time bootstrap configuration. It creates a
dedicated resource group, a private Azure Blob container, recovery controls,
and Microsoft Entra ID data-plane access for the Azure Terraform backend. Do
not add workload resources here: Terraform cannot initialize a backend that it
is creating in the same run.

The storage account deliberately has shared-key authorization disabled. State
access uses Microsoft Entra ID and the `Storage Blob Data Contributor` role;
no access key, SAS, or client secret belongs in the repository.

After the workload VNet and `privatelink.blob.core.windows.net` zone exist, the
bootstrap root can create an opt-in Blob Private Endpoint using
`private_endpoint_subnet_id` and `private_dns_zone_id`. Keep public access
enabled while creating and testing that endpoint; disable it only in a later
apply after private DNS and managed-identity Blob access succeed from the
private runner. The state root remains local-backend based so this operation
does not create a bootstrap/backend dependency cycle.

## Prerequisites

- An Azure principal that can create the resource group, storage account, and
  role assignments. The same principal must either already have `Storage Blob
  Data Contributor` on the new account or be listed in
  `state_operator_principal_ids`.
- A fixed Terraform-runner egress address in `allowed_ip_ranges`, or a
  private-network design with `public_network_access_enabled = false`. The
  storage firewall is deny-by-default even when public networking is enabled.
- Azure CLI or GitHub OIDC authentication. Do not use a client secret.

For an interactive bootstrap, authenticate with `az login`, select the target
subscription, then run:

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

If the bootstrap identity is granted by this configuration, Entra role
propagation can take several minutes before the container create succeeds.
Re-run the apply; do not re-enable shared keys as a workaround.

## Configure the production backend

The future Azure production root should contain an `azurerm` backend block
with no hard-coded credentials. In GitHub Actions, provide short-lived OIDC
environment variables such as `ARM_USE_OIDC=true`, `ARM_CLIENT_ID`,
`ARM_TENANT_ID`, and `ARM_SUBSCRIPTION_ID`; set `ARM_USE_AZUREAD=true` for
Microsoft Entra Blob authentication.

Then initialize with the generated non-secret settings:

```bash
terraform -chdir=../environments/prod init \
  -backend-config=../../bootstrap-state/backend.hcl
```

The `backend.hcl.example` file is only a template. Replace its placeholders
with outputs from this bootstrap, keep the real file uncommitted, and use a
distinct Blob key per environment.

## Recovery and access notes

- Blob versioning plus Blob/container soft delete provide recovery from an
  accidental state overwrite or deletion; they are not a backup substitute.
- Grant `Storage Blob Data Contributor` only to Terraform CI and break-glass
  operators. Azure management-plane roles alone do not permit Blob backend
  reads/writes.
- Before switching the storage firewall to private-only, ensure the runner has
  both private DNS and network access to the chosen private endpoint.
- Include the private runner or jump-host managed identity in
  `state_operator_principal_ids` so its data-plane role is Terraform-owned.
- Do not use storage keys, SAS tokens, connection strings, or anonymous access
  as a migration fallback.
