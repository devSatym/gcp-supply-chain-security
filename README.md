# Azure private DevSecOps supply chain

This repository builds a FastAPI demo image, signs and attests it, and runs it
only on private Azure Kubernetes Service (AKS). Azure is the active platform;
the pre-migration implementation remains recoverable from the immutable Git
tag `final-gcp-commit` and is not managed or destroyed by this repository.

## What is deployed

```text
GitHub hosted PR checks
  └─ secret scan, CodeQL, Semgrep, Trivy, Checkov, OPA, actionlint, zizmor

trusted refs/heads/main only
  └─ private Azure runner (no public IP)
       └─ GitHub OIDC -> ACR build/push -> Cosign keyless signature
            -> SPDX SBOM + SLSA provenance -> independent verification
            -> ACR digest lock -> reviewed GitOps values commit
            -> private Argo CD -> restricted supply-chain namespace on AKS
                 -> Kyverno image + workload policy -> Falco runtime detection
```

No client secret, storage key, ACR admin account, kubeconfig, or webhook is
stored in source control. AKS is private. Release images always use
`repository@sha256:<digest>`.

## One-time startup

The current environment values are non-secret and live in
[`infrastructure/azure/environments/prod/platform.auto.tfvars.json`](infrastructure/azure/environments/prod/platform.auto.tfvars.json).
The Azure Blob backend already exists. Run the following from an authenticated
owner workstation once; it creates the separate Terraform identity and the
no-public-IP runner, then registration makes all future trusted-main changes
automatic.

1. Export the non-secret remote-backend coordinates and an ephemeral VM public
   key. The public key is required by the Azure VM API, but there is no SSH
   network path to the VM.

   ```bash
   export TFSTATE_RESOURCE_GROUP_NAME=rg-scs-tfstate-eus
   export TFSTATE_STORAGE_ACCOUNT_NAME=stscs4c4dfbde
   export TFSTATE_CONTAINER_NAME=tfstate
   export TFSTATE_KEY=supply-chain-security/dev/terraform.tfstate

   key_dir="$(mktemp -d)"
   ssh-keygen -q -t ed25519 -N '' -f "$key_dir/runner"
   export TF_VAR_private_runner_admin_ssh_public_key="$(<"$key_dir/runner.pub")"
   ```

2. Apply the Azure foundation from a disposable Terraform data directory. It
   uses the existing remote Azure Blob state and refuses delete/replacement
   plans.

   ```bash
   TF_DATA_DIR="$(mktemp -d)" \
   scripts/azure/apply-once.sh --mode core \
     --var-file infrastructure/azure/environments/prod/platform.auto.tfvars.json
   ```

3. Set the runner name from the reviewed platform configuration and register
   it. Registration uses a short-lived GitHub token only in the encrypted Azure
   Run Command request; it is not written to state or a file.

   ```bash
   export AZURE_RESOURCE_GROUP=rg-scs-dev-eastus
   export AZURE_PRIVATE_RUNNER_NAME=scs-private-runner
   scripts/azure/register-private-runner.sh
   ```

4. Set the following **GitHub repository variables** from the corresponding
   Terraform outputs or the values above: `AZURE_TERRAFORM_CLIENT_ID`,
   `AZURE_PRIVATE_RUNNER_SSH_PUBLIC_KEY`, `TFSTATE_RESOURCE_GROUP_NAME`,
   `TFSTATE_STORAGE_ACCOUNT_NAME`, `TFSTATE_CONTAINER_NAME`, and
   `TFSTATE_KEY`. Existing `AZURE_CLIENT_ID`, tenant/subscription, ACR, AKS,
   and resource-group variables remain required for the release workflow.

5. Run `Azure Infrastructure Converge` once with confirmation `apply`, or push
   a trusted change to `main`. The runner uses GitHub OIDC and remote state to
   converge AKS add-ons, Argo CD, Kyverno, Falco, and the Azure GitOps
   Application. A verified `main` build then promotes a real digest and Argo
   deploys it automatically.

Delete the temporary key directory after the VM is created. It is not needed
for normal operation. Do not enable `--mode private` until the runner has
proven private DNS and HTTPS connectivity to every configured endpoint.

## Routine operations

- `Azure Infrastructure Converge` automatically applies a saved,
  non-destructive plan for trusted main changes.
- `Azure Drift Detection` produces a read-only OIDC plan on the private
  runner every weekday.
- `Azure Private DAST` runs OWASP ZAP through a temporary private `kubectl
  port-forward`; the application never receives a public endpoint.
- `TF_VAR_discord_webhook_url` is optional. Runtime alerting stays disabled
  until the owner explicitly enables it and supplies a Key Vault secret expiry.

Offline validation:

```bash
terraform fmt -check -recursive infrastructure/azure
helm lint k8s/azure/supply-chain-demo
python3 policy/azure/tests/check_workload_hardening.py
python3 policy/azure/tests/check_azure_policy_contract.py
bash -n scripts/azure/apply-once.sh scripts/azure/register-private-runner.sh
```

See [Azure controls and evidence](docs/azure/controls-matrix.md) and the
[incident runbook](docs/runbooks/azure-incident-response.md) for operational
details.
