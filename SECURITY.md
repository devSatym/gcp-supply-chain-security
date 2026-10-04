# Security policy

## Supported scope

Security fixes are maintained on `main`, the active Azure AKS/ACR
implementation. This is a pre-1.0 reference project with no security support
SLA. Older snapshots are not maintained release branches. The historical GCP
baseline at `final-gcp-commit` is an immutable archive and receives no fixes.

## Report a vulnerability privately

Use [GitHub private vulnerability reporting](https://github.com/devSatym/gcp-supply-chain-security/security/advisories/new).
Do not disclose exploitable findings in public issues or pull requests before
coordinating a fix with the repository owner.

Include the affected commit and files, expected and observed behavior,
potential impact, and minimal reproduction steps. Use local checks or an
isolated environment you control. Sanitized excerpts are sufficient; never
submit credentials, tokens, private keys, kubeconfigs, Terraform state, or
webhook secrets. The owner reviews reports and coordinates fixes and public
disclosure through GitHub advisories as appropriate.

For ordinary defects or feature requests, use the public issue templates.

## Security boundaries

Untrusted pull requests use GitHub-hosted static checks and local image
scans. Azure OIDC federation, signing, and promotion are bound to trusted
`refs/heads/main` execution. Release/convergence jobs use private runners;
manual drift/DAST dispatches still need review of runner scheduling guards.
AKS uses a private API; deployments use immutable image digests and independent
artifact verification.

See the [controls and evidence matrix](docs/azure/controls-matrix.md) for
implemented controls and documented exceptions, and the
[incident response runbook](docs/runbooks/azure-incident-response.md) for
operator procedures. Local checks alone do not prove live admission
enforcement, workload health, or alert delivery.
