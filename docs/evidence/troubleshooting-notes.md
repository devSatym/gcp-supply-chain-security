# Troubleshooting Notes — Gatekeeper + Ratify Setup

1. Ratify Helm install fails with "must provide a TLS certificate"
   Fix: --set featureFlags.RATIFY_CERT_ROTATION=true

2. Ratify Verifier stuck CONFIG_INVALID after fixing YAML
   Cause: kubectl apply does a merge, stale fields from earlier versions
   persist. Fix: kubectl delete then kubectl apply, not apply-over-apply.

3. Cosign trust policy field is `scopes`, not `registryScopes`
   (registryScopes is the Notation verifier's field name)

4. Gatekeeper Rego checked remote_data.errors only
   Ratify surfaces per-image failures under remote_data.responses with
   isSuccess: false, not remote_data.errors. Missing this check meant
   totalViolations stayed at 0 even when Ratify was correctly rejecting
   images.

5. Rego only checked spec.containers
   initContainers and ephemeralContainers were never evaluated, allowing
   an unsigned init container to bypass verification entirely.
