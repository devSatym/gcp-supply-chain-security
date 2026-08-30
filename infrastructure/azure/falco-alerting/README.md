# Azure Falco alerting module

This opt-in module creates the Azure equivalent of the GCP Falco alert path:

```text
Falco -> Falcosidekick (AKS workload identity) -> Event Hubs
      -> Azure Functions (managed identity) -> Key Vault -> Discord
```

It intentionally uses no Event Hubs SAS keys. Falcosidekick authenticates with
its AKS-federated user-assigned managed identity. The Function uses its
system-assigned identity for Event Hubs, Key Vault, and host storage.

Invoke this module only when `enable_runtime_alerting` is true in the
production root. Supply the webhook outside version control:

```bash
export TF_VAR_discord_webhook_url='https://discord.com/api/webhooks/REPLACE_ME'
export TF_VAR_discord_webhook_secret_version=1
```

The generated archive is intentionally ignored in `.build/`. A production
private-endpoint rollout must ensure both AKS and the Function have the
required private DNS/network paths before disabling public service endpoints.
