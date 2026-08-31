# Azure operational scripts

- `apply-once.sh` performs staged Azure convergence with existing remote Blob
  state, temporary Terraform data, saved plans, and private endpoint probes.
- `register-private-runner.sh` registers the no-public-IP VM as the repository
  runner using one short-lived GitHub registration token. It never writes that
  token to Terraform state or the runner service configuration.

Both scripts fail closed: they require the private AKS endpoint, Entra/OIDC
authentication, and the intended Azure resource names. Neither creates a
public AKS fallback or static cloud credential.
