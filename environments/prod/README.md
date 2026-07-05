# environments/prod

This is the **root module** — the thing you actually `terraform init`/`plan`/`apply`.
`vpc`, `gke`, and `kubernetes-addons` are reusable modules with no backend or
provider config of their own (correct practice); this directory supplies both.

## One-time setup

### 1. Create the state bucket (if you haven't already)
```bash
gsutil mb -l us-central1 gs://YOUR-TF-STATE-BUCKET
gsutil versioning set on gs://YOUR-TF-STATE-BUCKET
```

### 2. Copy the tfvars file
```bash
cp terraform.tfvars.example terraform.tfvars
```
Edit `terraform.tfvars` — at minimum confirm `project_id` matches your project
(`stoked-citizen-455416-g4`), and set `owner` / `project_label` / `cost_center`
to real values (these become required GCP labels — see `.infracost/policies/tagging.rego`).

### 3. Init with your backend bucket
```bash
terraform init \
  -backend-config="bucket=YOUR-TF-STATE-BUCKET" \
  -backend-config="prefix=gcp-infrastructure-modules/prod"
```

## ⚠️ Apply in two passes the first time

The `kubernetes` and `helm` providers in `versions.tf` are configured from
`module.gke`'s outputs (cluster endpoint + CA cert). On a **brand-new**
cluster those values don't exist yet when Terraform first evaluates provider
config, so a single `terraform apply` from zero will fail with a provider
configuration error. Standard fix — apply the network + cluster first, then
everything else:

```bash
terraform apply -target=module.vpc -target=module.gke
terraform apply
```

The second command picks up `kubernetes-addons` (and reconciles anything
`-target` skipped) now that the cluster genuinely exists. Every apply after
this one is a normal single `terraform apply`.

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
| terraform | >= 1.7.0 |
| google | >= 5.30.0 |
| google-beta | >= 5.30.0 |
| helm | >= 2.13.0 |
| kubernetes | >= 2.30.0 |
