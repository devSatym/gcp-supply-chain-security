# Contributing

This is a reference implementation of container supply-chain and runtime
security on Azure AKS and ACR. Focus contributions on reproducible controls,
clear evidence, and small changes that a reviewer can validate. Azure is the
active implementation; the historical GCP baseline is preserved at the
immutable `final-gcp-commit` tag.

## Before you start

- Read [the README](README.md), [the controls matrix](docs/azure/controls-matrix.md),
  and [the operating contract](AGENTS.md).
- Open a feature request before a substantial architecture or cost change.
  Bug fixes and focused documentation corrections can go directly to a PR.
- Report vulnerabilities through [the security policy](SECURITY.md).
- Branch from `main` and keep the change focused. Do not include Terraform
  state, provider caches, credentials, kubeconfigs, or generated release files.

## Preserve the security model

Pull requests run static checks and a local image scan on GitHub-hosted
runners. Azure OIDC federation, signing, and promotion are bound to trusted
`refs/heads/main` execution. Trusted release/convergence jobs use private
runners; manual drift/DAST scheduling guards still need review. Keep
GitHub-to-Azure authentication OIDC-only, AKS private, and deployed images
pinned by digest.

Changes to signing identity, provenance, policy, or workflows must keep their
trust contracts consistent. Do not add long-lived cloud credentials or weaken
policy enforcement to make a test pass. Owner-supplied Azure values and
optional paid services require an explicit decision; use documented
placeholders rather than inventing identifiers.

## Validate your change locally

Use checks relevant to the files you changed. The existing workflows in
[`.github/workflows`](.github/workflows) define the complete CI gates. These
checks do not require an Azure login or a running cluster:

```bash
git diff --check
python3 policy/azure/tests/check_azure_policy_contract.py
python3 policy/azure/tests/check_falco_contract.py
python3 policy/azure/tests/check_azure_gitops_contract.py
python3 policy/azure/tests/check_azure_automation_contract.py
python3 policy/azure/tests/check_workload_hardening.py
terraform fmt -check -recursive infrastructure/azure
helm lint k8s/azure/supply-chain-demo
helm template supply-chain-demo k8s/azure/supply-chain-demo \
  --values k8s/azure/supply-chain-demo/values.release.yaml.example \
  > /tmp/supply-chain-release.yaml
```

For workflow changes, run `actionlint .github/workflows/*.yml` and the workflow
security checks defined in `security.yml`. For shell changes, run `bash -n`
on each affected script. Terraform validation downloads providers; follow the
temporary-copy pattern in `azure-static-validation.yml` to avoid adding
provider caches or changing tracked lock files in the worktree.

Run policy negative fixtures through the offline contract tests. Live
deployment or admission testing belongs in an owner-approved isolated Azure
environment and must be reported separately from local validation.

## Submit a pull request

Explain the problem, resulting behavior, and any effect on security or cost.
List the checks you actually ran, their results, and any remaining live Azure
validation. Link only sanitized evidence; remove credentials and personal
account metadata before sharing it. A successful local check does not prove
deployment, admission enforcement, or runtime alert delivery.

Contributions are reviewed by the repository owner.
