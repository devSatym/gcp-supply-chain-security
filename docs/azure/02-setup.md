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

## 1. Bootstrap remote Terraform state once

The Azure Blob backend must exist before the production root initializes. Use
the isolated `infrastructure/azure/bootstrap-state` root with an ephemeral
local backend outside the repository, or use an existing approved bootstrap
procedure. That bootstrap exception is unavoidable because Terraform cannot
initialize a backend that it is creating in the same run.

The production root must then receive the resulting backend through
`--backend-config=/path/to/backend.hcl` or the four `TFSTATE_*` variables. The
one-command runner refuses to initialize a local production backend, prints no
backend values, and stores its temporary Terraform data outside the repository.

## 2. Run one-command convergence

Keep the owner-supplied non-secret production var-file uncommitted and keep the
Discord URL out of every file. From a host with private AKS DNS and network
access, run:

```bash
scripts/azure/apply-once.sh --mode core
```

The runner uses saved plan/apply pairs for the foundation and convergence. It
probes the private AKS API before invoking Helm/Kubernetes providers. Use the
private mode only after an owner-approved private GitHub runner is ready:

```bash
PRIVATE_GITHUB_RUNNER_READY=true scripts/azure/apply-once.sh --mode private
```

Private mode creates service endpoints, probes private DNS and port 443, and
only then disables public access for ACR and enabled alerting services. It
never makes the AKS API public and never uses `az aks get-credentials`.

## 3. Configure GitHub only after Terraform outputs exist

Set repository variables, not secrets, from the non-secret Terraform outputs:

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

Set `enable_runtime_alerting = true` in the production variables and export the
webhook only for the runner invocation. Increment the non-secret
`TF_VAR_discord_webhook_secret_version` value whenever the webhook rotates.
The value is sent to the write-only Key Vault field and is never placed in a
tfvars file, output, log, or generated artifact.
