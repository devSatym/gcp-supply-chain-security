# Infrastructure component

This directory is the imported infrastructure component of the canonical
`devSatym/gcp-supply-chain-security` monorepo. Its upstream sources are
recorded in [`docs/repository-merge.md`](../docs/repository-merge.md). The
modules remain reusable and composable; `environments/prod` supplies the
deployment-specific wiring.

`environments/prod` is the one place all of this actually gets deployed —
see [`environments/prod/README.md`](environments/prod/README.md) for the real
apply workflow, provider bootstrapping gotchas, and troubleshooting notes.

## Modules

| Module | What it does |
|---|---|
| [`vpc`](vpc/) | Private, VPC-native network with Cloud NAT and secondary ranges for GKE pods/services |
| [`gke`](gke/) | Private, regional GKE cluster — Workload Identity, per-node-pool least-privilege service accounts, shielded nodes, autoscaling node pools defined as a map |
| [`kubernetes-addons`](kubernetes-addons/) | Optional metrics-server and ExternalDNS only. It does **not** install Kyverno, Gatekeeper, or cert-manager. |
| [`falco`](falco/) | eBPF runtime detection (Falco + Falcosidekick) layered on top of separately installed Kyverno admission enforcement — detects what actually runs, not just what is allowed to |
| [`falco-alerting`](falco-alerting/) | Event-driven alert delivery: Pub/Sub → Cloud Function → Discord, decoupled from cluster lifecycle |

## Design

Infrastructure and CI/CD are treated as modular software systems, not one-off
scripts: reusable modules, composite CI actions, policy-as-code enforcement,
and runtime detection on top of admission control. Prevention (Kyverno) and
detection (Falco) are complementary layers, not either/or — admission control
answers "what is allowed to run," and Falco answers "what is actually
happening once it is running."

## Getting started

```bash
cd environments/prod
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: project_id, labels, and optional runtime alerting
terraform init -backend-config="bucket=YOUR-TF-STATE-BUCKET"
terraform apply -target=google_project_service.required -target=module.vpc -target=module.gke
terraform apply
```

Full details, including the two-pass-apply requirement on a brand-new
cluster and real troubleshooting notes from standing this up, are in
[`environments/prod/README.md`](environments/prod/README.md).

## Historical upstream attribution and references

- [`musaumakau/supply-chain-security`](https://github.com/musaumakau/supply-chain-security) — application/security-side source repository
- [`musaumakau/gcp-infrastructure-modules`](https://github.com/musaumakau/gcp-infrastructure-modules) — infrastructure-side source repository

These links are historical attribution, not the current runtime repository
identity. The active deployment repository is
`devSatym/gcp-supply-chain-security`.
