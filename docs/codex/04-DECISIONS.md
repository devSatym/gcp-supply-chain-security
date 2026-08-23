# Decisions

| Decision | Rationale | Status |
| --- | --- | --- |
| Keep the current two-parent history | It is the canonical monorepo history; old prompt SHAs are obsolete | Confirmed; no repair/rewrite |
| Keep one monorepo with `/infrastructure` | Preserves application and imported infrastructure boundaries | Confirmed |
| Preserve historical upstream files/evidence | Attribution and audit context must remain distinguishable from runtime config | Confirmed |
| Use Kyverno as the only admission engine | Gatekeeper/Ratify would add an unnecessary static-key compatibility path | Live |
| Install Kyverno separately by Helm | Executable Kubernetes add-ons do not install admission engines | Live, chart 3.9.0 |
| Use digest-pinned workloads | Admission verifies the exact immutable artifact | Live |
| Use GitHub OIDC → GCP WIF | Short-lived credentials remove CI JSON keys | Live and verified |
| Use a separate mutable Cosign metadata GAR repository | Cosign v2 legacy `.sig`/`.att` indexes append to tags; the primary image repository remains immutable | Live and verified |
| Give Kyverno a repository-scoped reader GSA | Kyverno must read both primary images and metadata through GKE Workload Identity | Live and verified |
| Prefer Falcosidekick GKE Workload Identity | Falcosidekick ADC works with empty credentials; no static key is needed | Code/live Falco path ready; alerting disabled |
| Use Argo CD for application deployment | Git desired state is the deployment record | Live and healthy |
| Keep runtime alerting opt-in | No Discord webhook was supplied; Terraform must not create a fake secret or function | Confirmed |
| Keep node-pool sizes as total counts | Prevents unintended regional overprovisioning; autoscaler bounds are 1–2 nodes | Live |
| Keep Gatekeeper/Ratify/cert-manager/ExternalDNS disabled | Outside final portfolio scope | Confirmed |
| Separate PR image validation from trusted Deploy | PR Check owns all unprivileged PR gates; Deploy is main/manual only, so PR UI contains no misleading skipped production jobs | Implemented for clean PR evidence |
| Restrict trusted manual dispatch to canonical main | A typed confirmation alone does not constrain the selected ref; privileged WIF/GAR jobs now require `refs/heads/main` | Implemented and validated |
| Fail closed on provenance contract details in CI | Verification now asserts predicate, subject digest, builder, entrypoint, source URI, and source commit instead of merely printing provenance fields | Implemented and validated |
| Defer a blocking IaC/config scan until baselined | Current repository has genuine GKE findings, intentionally insecure fixtures, and an observed old-Trivy misconfiguration scan failure | Follow-up hardening |
| Do not apply the GitHub ruleset automatically | Branch protection can affect recovery; Terraform definition exists but remote rulesets are currently absent | Requires explicit approval |

## History validation record

- Previous blocker: master prompt referenced obsolete pre-rewrite SHA values.
- Resolution: current canonical merge `6717e4491d3e8a2d0b6fd6044a673041f30d040c`
  has application parent `cc1fa07a617320a8efdf31bb9aa67927128bd3a0`, infrastructure
  parent `c88320f1b2ac1995aa1d75f481e1f69d7063c2ba`, and both are ancestors of
  `HEAD`.
- History repair performed: **NO**.
- History rewrite performed during this implementation: **NO**.
