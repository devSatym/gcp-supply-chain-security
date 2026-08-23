# Interview Guide

## Explain the trust chain

A pull request runs policy and security scans. A merge to `main` exchanges a
GitHub OIDC token through a provider scoped to this repository, pushes an
immutable GAR image, scans it with Trivy, and signs the exact digest with
Cosign keyless identity. The workflow adds SPDX and SLSA attestations and
verifies them before Argo CD reconciles the Helm chart. Kyverno verifies the
digest, signer, Rekor proof, SBOM, and provenance before admission.

## Why two GAR repositories?

The primary application repository has immutable tags. Cosign v2 legacy
`.sig`/`.att` index tags need append/update behavior when multiple attestations
are added, so the metadata indexes live in a separate mutable repository. The
metadata still references and verifies the immutable primary digest; mutability
does not grant a different image or signer trust.

## Why not a JSON key?

GitHub Actions uses short-lived WIF credentials. Kyverno and the intended
Falcosidekick path use GKE Workload Identity and repository/topic-scoped GCP
roles. There is no long-lived key to rotate or exfiltrate.

## Why Kyverno instead of Gatekeeper/Ratify?

Kyverno natively verifies Cosign signatures and attestations at admission. The
imported Gatekeeper/Ratify material is retained for provenance comparison but
its legacy GAR authentication path requires a static key, so it is disabled in
the final deployment.

## How were bypasses tested?

The positive fixture used the exact signed digest. Negative fixtures covered a
real unsigned GAR image, an unsigned initContainer paired with a signed main
container, and a known signed digest evaluated under intentionally wrong signer
and provenance-source expectations. Each was denied by the API server.

## What does Falco add?

Admission answers “may this image start?” Falco answers “what does the running
process do?” The controlled `kubectl exec` shell was detected by the custom
rule at CRITICAL priority. Pub/Sub/Discord routing is an optional next step,
not a prerequisite for the runtime detection proof.

## Honest limitations to mention

- PR-only Semgrep/Trivy contexts still need a real review-branch capture before
  remotely activating the ruleset.
- The live node pool autoscaled from its configured total range of 1–2 nodes;
  regional capacity should be sized against quota and cost expectations.
- The Discord webhook was intentionally not supplied, so external notification
  is not claimed as complete.
