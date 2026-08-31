# environments/prod

This is the **root module** — the thing you actually `terraform init`/`plan`/`apply`.
`vpc`, `gke`, `kubernetes-addons`, `falco`, and `falco-alerting` are reusable
modules with no backend or provider config of their own (correct practice);
this directory supplies both.

## One-time setup

### 1. Select and create a dedicated state bucket

Choose the target project and bucket location before any apply. Do not reuse the
imported upstream state bucket or a bucket that holds another project. Enable
uniform bucket-level access and versioning:

```bash
gcloud storage buckets create gs://YOUR-TF-STATE-BUCKET \
  --project=YOUR_GCP_PROJECT_ID \
  --location=YOUR_STATE_BUCKET_LOCATION \
  --uniform-bucket-level-access
gsutil versioning set on gs://YOUR-TF-STATE-BUCKET
```

### 2. Copy the tfvars file
```bash
cp terraform.tfvars.example terraform.tfvars
```
Edit `terraform.tfvars` — at minimum set `project_id` to the accepted target
project and set `owner` / `project_label` / `cost_center`
to real values (these become required GCP labels — see `.infracost/policies/tagging.rego`).

Falco alerting is off by default. Only after creating a Discord incoming webhook
should you set the non-secret `enable_runtime_alerting = true` in this ignored
file, then pass the URL through the process environment:

```bash
export TF_VAR_discord_webhook_url='YOUR_NEW_DISCORD_WEBHOOK_URL'
export TF_VAR_discord_webhook_secret_version=1
```

Terraform maps `TF_VAR_*` names to input variables. The URL is sent to Secret
Manager through a write-only provider argument, so it is not retained in a
Terraform plan or state. Increment the version value whenever the URL rotates.
Never commit or paste the URL into a log.

### 3. Init with your backend bucket
```bash
terraform init \
  -backend-config="bucket=YOUR-TF-STATE-BUCKET" \
  -backend-config="prefix=gcp-supply-chain-security/prod"
```

## ⚠️ Apply in two passes the first time

The `kubernetes` and `helm` providers in `versions.tf` are configured from
`module.gke`'s outputs (cluster endpoint + CA cert). On a **brand-new**
cluster those values don't exist yet when Terraform first evaluates provider
config, so a single `terraform apply` from zero will fail with a provider
configuration error. Standard fix — apply the network + cluster first, then
everything else:

```bash
terraform apply \
  -target=google_project_service.required \
  -target=module.vpc \
  -target=module.gke
terraform apply
```

The second command picks up the GAR/WIF foundation, optional add-ons, Falco,
and (only if enabled) Falco alerting, then reconciles anything the targeted
apply skipped. Every apply after this one is a normal single `terraform apply`.

## Everyday use

```bash
terraform plan
terraform apply
```

## Get kubectl access

```bash
terraform output -raw get_credentials_command | bash
kubectl get nodes
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.11.0 |
| google | >= 7.0.0, < 8.0.0 |
| google-beta | >= 5.30.0, < 8.0.0 |
| helm | >= 2.13.0, < 3.0.0 |
| kubernetes | >= 2.30.0, < 3.0.0 |

---

## Falco runtime detection

Falco (eBPF, `modern_ebpf` driver) + Falcosidekick provide runtime detection
on top of Kyverno admission enforcement. Kyverno answers "what is allowed to
run"; Falco answers "what is actually happening once it is running." When
runtime alerting is enabled, alerts flow: Falco → Falcosidekick → Pub/Sub →
Cloud Function → Discord.

### Falcosidekick uses GKE Workload Identity

The Falco chart's embedded Falcosidekick release creates the deterministic
Kubernetes ServiceAccount `falco-falcosidekick`. Terraform binds that KSA to a
dedicated GSA using `roles/iam.workloadIdentityUser`, annotates it with
`iam.gke.io/gcp-service-account`, and grants the GSA only
`roles/pubsub.publisher` on the alert topic. Falcosidekick leaves
`config.gcp.credentials` empty, so its Pub/Sub client uses Application Default
Credentials from GKE Workload Identity. No JSON key is generated or stored.

### Troubleshooting

Real problems hit standing this up, kept here so the next debugging session
doesn't start from zero.

1. **Custom Falco rule loads cleanly (`falco -L` shows it `enabled: true`,
   correct condition) but never fires — while a broad default rule fires on
   the identical event, every time.**
   Root cause: since Falco 0.36.0, the default `rule_matching` behavior is
   `first` — Falco stops evaluating further rules against an event the
   moment ANY rule matches. A broad built-in rule (e.g. `Terminal shell in
   container`) will silently prevent a more specific custom rule from ever
   firing on the same event, with no error or warning anywhere. Confirmed
   via live testing across dozens of exec events, a full DaemonSet restart,
   and elimination testing down to bare single-condition rules under fresh
   names — the custom rule genuinely never fired until this was set.
   Fix, set in `modules/falco/main.tf`'s Helm values:
   ```hcl
   falco = {
     rule_matching = "all"
   }
   ```
   Reference: https://github.com/falcosecurity/falco/issues/2891

2. **`kubectl patch configmap falco-custom-rules` succeeds with no error,
   but the pod's mounted rules file never changes.**
   The Falco Helm chart auto-generates its own ConfigMap from the
   `customRules` values key (named `falco-rules` in this deployment) — it's
   a *different* object than any ConfigMap you create yourself in Terraform
   under a different name. A `kubernetes_config_map` resource with a name
   that doesn't match the chart's auto-generated one gets created but never
   mounted into any pod — silently inert. Confirm what's actually mounted
   before debugging rule content:
   ```bash
   kubectl -n falco-system get pod <falco-pod> -o jsonpath='{.spec.volumes[*].configMap.name}'
   ```

3. **Falcosidekick logs `PermissionDenied` on `pubsub.topics.publish` even
   though the GSA has `roles/pubsub.publisher` and Workload Identity is
   correctly bound.**
   Check the `falco-falcosidekick` ServiceAccount annotation, the exact
   `falco-system/falco-falcosidekick` Workload Identity member binding, and the
   topic-level publisher grant. Do not fall back to a JSON key.

4. **Gatekeeper install/upgrade fails cluster-wide: `no endpoints available
   for service "gatekeeper-webhook-service"`, and even unrelated resources
   (e.g. `kube-dns`) fail to patch with the identical error.**
   This is a self-inflicted admission deadlock: the **mutating** webhook
   (`gatekeeper-mutating-webhook-configuration`, not the validating one) runs
   `failurePolicy: Fail` and matches almost all cluster resources. If its
   backend Service briefly has zero live endpoints (e.g. during a rollout),
   the API server starts rejecting nearly every write cluster-wide —
   including the writes needed to fix the endpoints or restart the pods
   that would restore them. Fix: delete the mutating webhook outright (this
   repo uses digest-pinned images, so it provides no benefit anyway):
   ```bash
   kubectl delete mutatingwebhookconfiguration gatekeeper-mutating-webhook-configuration
   ```
   Endpoints repopulate immediately once the deadlock is broken.

5. **Falco Helm chart version pinned in Terraform silently goes stale.**
   Chart versions move fast; don't trust a hardcoded default. Verify before
   relying on it:
   ```bash
   helm search repo falcosecurity/falco --versions | head -5
   ```

6. **Helm provider `kubernetes {}` nested block throws `Unsupported block
   type` after an unconstrained `terraform init`.**
   Helm provider v3.0.0 migrated to the Terraform Plugin Framework and
   removed the inline `kubernetes {}` config block from the `helm` provider
   entirely — that syntax is v2.x-only. If `versions.tf` doesn't pin
   `hashicorp/helm` below v3 (`~> 2.12`), `terraform init` grabs the latest
   major and this breaks. Same applies to the `kubernetes` provider's
   resource naming (`kubernetes_namespace` deprecated in favor of
   `kubernetes_namespace_v1` starting in v3) — pin both providers explicitly.
