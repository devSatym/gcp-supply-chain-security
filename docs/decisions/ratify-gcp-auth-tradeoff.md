# Decision: Ratify GAR Authentication — Static JSON Key

**Status:** Accepted  
**Date:** 2026-07-13  
**Component:** OPA Gatekeeper + Ratify (supply-chain-security)

---

## Context

This repo uses OPA Gatekeeper with Ratify (`notaryproject/ratify`) as an external-data
provider to enforce cryptographic signature verification at admission time. Ratify needs
read access to Google Artifact Registry (GAR) to pull Cosign signatures and attestations
stored alongside images.

Everywhere else in this pipeline, authentication uses short-lived credentials with no
stored secrets:
- GitHub Actions → GCP: Workload Identity Federation (OIDC token exchange)
- Kyverno → GAR: GKE Workload Identity (KSA → GSA binding via metadata server)

The question was whether Ratify could follow the same pattern.

---

## Decision

Ratify authenticates to GAR using a **long-lived JSON service account key**, stored as
a `kubernetes.io/dockerconfigjson` Secret in `gatekeeper-system`, referenced via
Ratify's `k8Secrets` authProvider.

This is a deliberate, documented exception to the otherwise-keyless posture of this
pipeline — not a shortcut.

---

## Alternatives Considered

### 1. GKE Workload Identity (KSA → GSA binding)
**Rejected.** Ratify's ORAS store `authProvider` list does not include a GCP Workload
Identity provider. The supported providers are: `azureWorkloadIdentity`,
`azureManagedIdentity`, `awsEcrBasic`, Alibaba Cloud RRSA, and `k8Secrets`. No GCP
equivalent exists upstream (checked against `notaryproject/ratify` main branch,
July 2026; no open PR or issue tracking this).

### 2. CronJob token refresh (gcloud access token → k8s Secret update)
**Rejected.** GCP OAuth2 access tokens expire in 1 hour. Ratify's `k8Secrets` provider
hardcodes a 12-hour credential TTL regardless of how often the underlying Secret is
updated:

```go
// pkg/common/oras/authprovider/k8secret_authprovider.go
const secretTimeout = time.Hour * 12

return AuthConfig{
    ...
    ExpiresOn: time.Now().Add(secretTimeout),
}, nil
```

Ratify's auth-caching layer uses `ExpiresOn` to decide when to re-call `Provide()`.
Even if a CronJob wrote a fresh token every 50 minutes, Ratify would keep using the
initial token — now expired — for up to 11 hours. The staleness window is baked into
Ratify's source as a hardcoded constant, not configurable via Helm or CRD.

### 3. External Secrets Operator (ESO) token refresh
**Rejected.** Same root cause as option 2. ESO can keep the Secret content fresh, but
Ratify's 12h `ExpiresOn` means it ignores Secret updates until the TTL runs out. ESO
adds complexity without fixing the problem.

### 4. GCP Workload Identity Federation (external OIDC → GCP STS)
**Not applicable.** WIF is a mechanism for *external* workloads to exchange an OIDC
token for a short-lived GCP access token. Ratify runs inside GKE and would still need
an auth provider that calls the GCP STS endpoint with the KSA OIDC token — which
doesn't exist in Ratify's provider list (same gap as option 1).

---

## Mitigations

Since this key breaks the keyless pattern used elsewhere, the following controls are
in place to reduce risk:

| Control | Implementation |
|---------|---------------|
| Minimal scope | IAM binding is repo-scoped (`supply-chain-security` repo only), not project-wide `artifactregistry.reader` |
| Dedicated identity | Separate GSA `ratify-gar-reader@...` — not shared with any other workload |
| Secret hygiene | Key never committed to git; created via `create-ratify-secret.sh` from Terraform output; `.gitignore` covers `*.json` and `*.key` |
| Rotation schedule | 90-day rotation via `terraform apply -replace=google_service_account_key.ratify_gar_reader` + re-run of secret creation script |
| Terraform-managed | Key lifecycle tracked in GCS-backed Terraform state (server-side encrypted), not manually created |
| Documented | This ADR explains the trade-off to anyone auditing the pipeline |

---

## Consequences

- Ratify can authenticate to GAR reliably for the lifetime of the key.
- One component in an otherwise-keyless pipeline requires periodic manual rotation.
- If Ratify adds a GCP Workload Identity auth provider upstream, this exception should
  be removed and replaced with a KSA → GSA binding matching the Kyverno pattern.
- The 90-day rotation reminder is the primary operational burden introduced by this
  decision.
