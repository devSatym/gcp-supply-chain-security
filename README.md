# gcp-infrastructure-modules

Reusable Terraform modules for GCP infrastructure, mirroring the AWS blueprint
in [`infrastructure-modules`](https://github.com/musaumakau/infrastructure-modules):
modular, composable, no hardcoded environment values, each module independently
usable and independently tested via its own `examples/complete`.

`environments/prod` is the one place all of this actually gets deployed —
see [`environments/prod/README.md`](environments/prod/README.md) for the real
apply workflow, provider bootstrapping gotchas, and troubleshooting notes.

## Modules

| Module | What it does |
|---|---|
| [`vpc`](vpc/) | Private, VPC-native network with Cloud NAT and secondary ranges for GKE pods/services |
| [`gke`](gke/) | Private, regional GKE cluster — Workload Identity, per-node-pool least-privilege service accounts, shielded nodes, autoscaling node pools defined as a map |
| [`kubernetes-addons`](kubernetes-addons/) | Cluster addons deployed via Terraform's `helm_release` — Kyverno, Gatekeeper, cert-manager, external-dns |
| [`falco`](falco/) | eBPF runtime detection (Falco + Falcosidekick) layered on top of the admission-time enforcement in `kubernetes-addons` — detects what actually runs, not just what's allowed to |
| [`falco-alerting`](falco-alerting/) | Event-driven alert delivery: Pub/Sub → Cloud Function → Discord, decoupled from cluster lifecycle |

## Design

Infrastructure and CI/CD are treated as modular software systems, not one-off
scripts: reusable modules, composite CI actions, policy-as-code enforcement,
and now runtime detection on top of admission control. Prevention (Kyverno,
Gatekeeper/Ratify — see [`supply-chain-security`](https://github.com/musaumakau/supply-chain-security))
and detection (Falco) are treated as complementary layers, not either/or —
admission control answers "what's allowed to run," Falco answers "what's
actually happening once it's running."

## Getting started

```bash
cd environments/prod
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: project_id, discord_webhook_url, etc.
terraform init -backend-config="bucket=YOUR-TF-STATE-BUCKET"
terraform apply -target=module.vpc -target=module.gke   # first apply only
terraform apply
```

Full details, including the two-pass-apply requirement on a brand-new
cluster and real troubleshooting notes from standing this up, are in
[`environments/prod/README.md`](environments/prod/README.md).

## Related repos

- [`infrastructure-modules`](https://github.com/musaumakau/infrastructure-modules) — the AWS equivalent of this repo
- [`supply-chain-security`](https://github.com/musaumakau/supply-chain-security) — the full CI/CD signing/attestation pipeline and admission enforcement this repo's `kubernetes-addons` module deploys
- [`kyverno-policy-pack`](https://github.com/musaumakau/kyverno-policy-pack) — the standalone, tested Kyverno policy set used by `kubernetes-addons`