# Decisions

## Confirmed during audit

| Decision | Rationale | Status |
| --- | --- | --- |
| Keep one monorepo with infrastructure under `/infrastructure` | It preserves the two component boundaries without creating separate deployment repositories | Confirmed structurally and by the canonical two-parent merge |
| Preserve historical upstream files | Gatekeeper/Ratify, examples, nested workflows, evidence, and documentation are provenance material | Confirmed |
| Keep nested infrastructure workflow inactive | GitHub does not execute nested workflows and the retained one has old root paths and assumptions | Confirmed: preserve only |
| Deploy Kyverno only | The final scope names Kyverno as the actual admission engine; Gatekeeper/Ratify would introduce an unneeded static-key path | Confirmed target, not yet deployed |
| Use digest-pinned workloads | A digest fixes the exact artifact admitted by Kyverno | Confirmed target; current digest is historical only |
| Use GitHub OIDC → GCP WIF for CI | The existing design uses short-lived credentials; no CI JSON key exists in active workflows | Confirmed target, not yet validated on the final identity |
| Use Cosign keyless signing | The pipeline uses GitHub OIDC/Sigstore and stores no signing key | Confirmed target, not yet validated personally |
| Separate admission from runtime security | Kyverno controls admission; Falco observes behavior after execution | Confirmed |
| Retain Falco | It is in scope for controlled runtime detection and alerting | Confirmed target |
| Prefer Falcosidekick GKE Workload Identity | Pinned chart supports a GCP service-account annotation and ADC fallback; current static-key claim is stale | Confirmed design, pending live validation |
| Use Argo CD for GitOps | The intended deployment record is Git desired state, not a final direct `kubectl apply` | Confirmed target |
| Exclude observability stack, custom domain/Ingress, and platform features | They do not strengthen the stated DevSecOps supply-chain story | Confirmed |

## Pending decisions

1. Confirm the GCP target project, region, billing, quota, and a unique GCS state bucket.
2. Confirm whether to use a Discord webhook for the alerting proof.
3. Confirm the final personal GAR repository name if a collision exists.

## History validation record

- Previous blocker: the master prompt referenced obsolete pre-rewrite SHA values.
- Resolution: current canonical monorepo topology independently verified (`6717e449…` with application-side parent `cc1fa07…` and infrastructure-side parent `c88320f…`).
- History repair performed: **no**.
- History rewrite performed during this implementation: **no**.
