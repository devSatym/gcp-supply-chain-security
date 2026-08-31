# Azure incident response runbook

## Suspected credential or workflow compromise

1. Disable the affected GitHub Actions workflow and remove the relevant Azure
   federated identity credential. Do not add a client secret as a workaround.
2. Revoke the GitHub runner registration and stop the private runner VM using
   Azure control-plane access. Preserve VM boot diagnostics and GitHub job logs.
3. Review GitHub Security alerts, workflow runs, Azure Activity Log, ACR
   repository events, Key Vault diagnostics (if alerting is enabled), and Falco
   events for the relevant time range.
4. Recreate the managed identity/federated credential with the exact immutable
   `refs/heads/main` subject, register a freshly patched runner, and rerun the
   Azure static validation before re-enabling release automation.

## Suspicious workload or admission bypass

1. Quarantine the workload by scaling the Argo-managed Deployment to zero in a
   reviewed emergency commit; do not disable Kyverno globally.
2. Capture the Pod spec, image digest, Kyverno policy report, Falco event, and
   ACR signature/SBOM/provenance verification output.
3. Confirm the promoted `values.release.yaml` references the affected digest.
   Lock or quarantine the ACR manifest; do not overwrite a verified digest.
4. Fix and validate the policy or image, then promote a new signed digest from
   trusted main. Argo reconciles the replacement automatically.

## Remote state recovery

1. Stop automatic convergence and inspect the Blob version history.
2. Restore only the intended prior Blob version after reviewing the Terraform
   plan in a disposable `TF_DATA_DIR`.
3. Keep shared-key access disabled. Use Entra authorization or GitHub OIDC for
   recovery; never download or commit storage keys.
