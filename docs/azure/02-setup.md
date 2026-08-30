# Azure setup and bootstrap

## Prerequisites

- Azure CLI authenticated to the intended tenant/subscription.
- Permission to create resource groups, managed identities, federated identity
  credentials, role assignments, AKS, networking, Storage, ACR, Event Hubs,
  Key Vault, and Functions.
- Terraform 1.11 or newer.
- A controlled runner/administrator host that can reach the private AKS API for
  the add-on phase.
- GitHub repository administrator access to configure non-secret Azure
  variables after Terraform exports the UAMI client ID and ACR login server.

Register required resource providers before the first plan (registration can
take several minutes):

```bash
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.ManagedIdentity
az provider register --namespace Microsoft.EventHub
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.Web
az provider register --namespace Microsoft.OperationalInsights
```

## 1. Bootstrap remote Terraform state

The Azure Blob backend must exist before the production root initializes. Use
the isolated `infrastructure/azure/bootstrap-state` root with a local backend
first. Its output supplies the storage account, resource group, and container
for the production backend.

```bash
cd infrastructure/azure/bootstrap-state
terraform init -backend=false
terraform plan -out bootstrap.tfplan
terraform apply bootstrap.tfplan
```

The identity running Terraform needs `Storage Blob Data Contributor` on that
state storage account. Use Microsoft Entra authentication; do not enable or
export a Storage Account access key for Terraform state.

## 2. Configure the production root

Copy the Azure example values and fill in non-secret subscription, tenant,
network, owner, and cost inputs. Keep the Discord URL out of every file.

```bash
cd ../environments/prod
cp terraform.tfvars.example terraform.tfvars
terraform init \
  -backend-config='resource_group_name=REPLACE_STATE_RESOURCE_GROUP' \
  -backend-config='storage_account_name=REPLACE_STATE_STORAGE_ACCOUNT' \
  -backend-config='container_name=tfstate' \
  -backend-config='key=azure-supply-chain-security/prod.tfstate' \
  -backend-config='use_azuread_auth=true'
terraform plan
```

Use the staged sequence documented by the root README: provisioning network and
AKS first, then run Helm/Kubernetes provider work from the private-network
operator host.

## 3. Configure GitHub only after Terraform outputs exist

Set repository variables, not secrets:

| Variable | Source |
|---|---|
| `AZURE_CLIENT_ID` | GitHub CI UAMI Terraform output |
| `AZURE_TENANT_ID` | Azure tenant input/output |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription input/output |
| `ACR_LOGIN_SERVER` | ACR Terraform output |
| `ACR_REPOSITORY` | Application repository Terraform output |
| `COSIGN_REPOSITORY` | Mutable metadata repository Terraform output |

Keep the federated credential subject restricted to the canonical repository
and `refs/heads/main`. A branch must not receive registry-write authority
without a deliberate protected-environment/release-policy change.

## Optional runtime alerting

Only when a real Discord destination is authorized:

```bash
export TF_VAR_discord_webhook_url='https://discord.com/api/webhooks/REPLACE_ME'
export TF_VAR_discord_webhook_secret_version=1
```

Set `enable_runtime_alerting = true` in the production variables, apply from a
controlled host, then follow the live validation checklist. Increment the
non-secret secret-version value whenever the webhook rotates.
