# Azure one-command convergence

After the one-time `bootstrap-state` root has created the Azure Blob backend,
run the production convergence from a host that can resolve and reach the
private AKS API:

```bash
scripts/azure/apply-once.sh --mode core
```

The command initializes the existing `azurerm` backend with Microsoft Entra
authentication, runs saved-plan/apply pairs in dependency order, and keeps all
Terraform data, provider files, logs, and plans in a disposable directory
outside the repository. It never falls back to local state or a public AKS API.

`core` converges private AKS, Kyverno, Falco, Argo CD, and the Terraform-installed
Argo Application. `private` additionally creates the ACR and optional alerting
Private Endpoints, probes private DNS/443 for every enabled service, and only
then closes public service access:

```bash
PRIVATE_GITHUB_RUNNER_READY=true scripts/azure/apply-once.sh --mode private
```

The private mode acknowledgement is required because closing ACR access would
break hosted GitHub runners. It does not create a runner or invent GitHub
configuration. Set `TF_VAR_discord_webhook_url` only when the owner has
explicitly enabled runtime alerting; the value is passed directly to the
write-only Key Vault field and is never printed or written to a file.

## One-time backend bootstrap

Terraform cannot initialize a backend that it creates in the same run. Run
`infrastructure/azure/bootstrap-state` once with owner-supplied values and keep
its temporary local state outside the repository, or use an existing approved
bootstrap procedure. The production command accepts either:

- `--backend-config=/path/to/backend.hcl`, or
- `TFSTATE_RESOURCE_GROUP_NAME`, `TFSTATE_STORAGE_ACCOUNT_NAME`,
  `TFSTATE_CONTAINER_NAME`, and `TFSTATE_KEY` environment variables. An
  ignored `.codex/azure-values.env` may provide those non-secret names locally.

Do not commit backend files containing live identifiers, Terraform state,
provider caches, kubeconfigs, or credentials. A successful infrastructure run
means the platform is converged; the demo workload appears only after the
trusted `refs/heads/main` image workflow verifies and promotes a real
`repository@sha256:<digest>` release.
