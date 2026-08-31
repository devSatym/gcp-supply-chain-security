# Azure operations and assurance

Azure is the active deployment platform. The source is designed for a public
GitHub repository with a private runner: untrusted pull requests are limited
to GitHub-hosted static checks, while only `refs/heads/main` may select the
private runner or exchange an OIDC token for Azure access.

- [Controls and evidence matrix](controls-matrix.md)
- [Incident response runbook](../runbooks/azure-incident-response.md)
- [Root startup guide](../../README.md#one-time-startup)
