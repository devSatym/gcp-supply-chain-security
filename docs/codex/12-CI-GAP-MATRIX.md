# CI / DevSecOps Gap Matrix

This matrix compares the intended controls in plan.md with the current
executable implementation. Severity reflects the current production risk, not
the presence of a cosmetic skipped check.

| ID | Area | Plan requires | Current implementation | Gap? | Severity | Fix | Validation |
| --- | --- | --- | --- | --- | --- | --- | --- |
| CI-001 | Provenance verification | Verification must fail when the expected SLSA predicate, source repository, builder, and signing workflow entrypoint do not match. | Verify now uses exact certificate identity matching and fail-closed jq assertions for signature digest, SPDX predicate/subject, and SLSA predicate/subject/builder/entrypoint/source URI/source commit/material. | No — fixed | HIGH (fixed) | Implemented in `verify.yml`. | actionlint; policy tests; main Verify job in run `32638968765` passed all three checks. |
| CI-002 | Trusted manual dispatch scope | Trusted GAR/WIF/signing work must originate from main, not an arbitrary selected branch. | Privileged Deploy jobs now require `github.ref == 'refs/heads/main'`; manual dispatch also requires the existing typed confirmation. Sign and Verify independently require main. | No — fixed | HIGH (fixed) | Implemented in `deploy.yml`. | Static condition review; actionlint; PR #2 skipped production jobs; main run `32638968765` passed. |
| CI-003 | Terraform/IaC security scan | The project has Terraform and Kubernetes configuration; plan.md calls for filesystem/config/IaC scanning as appropriate. | Active Infrastructure Terraform performs format, init backend=false, and validate. PR Trivy fs defaults to vuln,secret and does not select misconfig. No active Checkov/tfsec/TFLint/Trivy config gate exists. | Yes | MEDIUM | Establish a reviewed configuration baseline before adding a version-pinned, fail-closed IaC scan. The audit found genuine/intentional findings and Trivy 0.70 panics when misconfig scans the full repository. | Resolve or scope GCP-0048, GCP-0061, and intentionally insecure negative fixtures; run selected scanner in PR and confirm a known bad IaC fixture blocks. |
| CI-004 | Required PR checks / branch protection | plan.md describes protected main as desirable and Terraform defines a ruleset with Semgrep, Trivy, and policy checks. | Remote rulesets API returned an empty list. The Terraform configuration exists but is not applied. The legacy branch-protection endpoint also returned 404. | Yes | MEDIUM | Do not apply automatically. Obtain explicit approval, review the Terraform plan, then apply only the GitHub ruleset state. | GitHub rulesets API shows main-branch-protection active; a PR requires the three configured contexts before merge. |
| CI-005 | Main artifact scan order | A trusted/deployed artifact must pass final image scanning before signing. | Main path is build and push -> scan immutable GAR digest -> sign/attest -> verify. An unsigned version is briefly present in GAR but cannot meet Kyverno policy. | No | INFO | Keep order. Consider a future staging/promotion registry only if the project requires no unscanned registry versions at all. | Successful main run records scan before sign. |
| CI-006 | GitOps digest handoff | Argo must deploy a pinned trusted digest, never latest or a tag-only reference. | No CI Git writer exists. A human manually pins the verified digest in Helm values. Current Helm digest maps to successful trusted run 32629860698 and Argo/Kyverno consume a digest. | No | INFO | Keep the documented manual-promotion model. Record source run/digest whenever changing Helm values. | GAR tag/source run, Helm values, Argo revision, and Kyverno admission all agree. |
| CI-007 | PR privileged jobs shown as skipped | PR should validate code without producing trusted production artifacts. | Deploy is PR-triggered for local image scanning; its build/push, SBOM/VEX, sign, and verify jobs show skipped. | No | INFO | Keep. Do not make privileged jobs run merely to remove skipped labels. | PR run 32636629034 shows only local scan running. |
| CI-008 | Semgrep retained upstream workflow handling | Active CI must block relevant Semgrep findings without deleting historic inactive source. | Semgrep uses config auto, SARIF, and explicit post-upload enforcement. The only ignore is the non-active nested upstream workflow. | No | INFO | Keep the narrowly documented ignore and active root workflow coverage. | PR run 32636629041 passed; a Semgrep violation previously caused the enforcement step to fail. |
| CI-009 | VEX/reachability failure handling | The required trust SBOM is SPDX; VEX enforcement is outside deployment scope. | SBOM/VEX is explicitly named non-blocking and uses continue-on-error plus || true for depscan. The required SPDX SBOM is separately generated/attested/verified in Sign and Attest. | No | INFO | Keep the job non-blocking and retain clear naming. Do not treat it as the SPDX trust gate. | Main run 32630716371 completed both its supplementary job and required trust chain. |
| CI-010 | Root CI permissions | PR jobs should avoid write-capable repository/cloud credentials; main jobs should use least privilege. | No write-all, contents write, packages write, pull_request_target, or GCP auth in PR code path. PR Image Scan overrides out id-token. Main build/sign/verify need id-token and registry access. | No | INFO | Keep current job-level PR override and pinned actions. | Source review and PR run job list. |
| CI-011 | Root runtime identity consistency | WIF, Cosign, provenance, Kyverno, and Argo must use devSatym/gcp-supply-chain-security where runtime trust applies. | Active WIF provider condition, Terraform variable validation, Argo Applications, Helm source, CI provenance, verification signer, and Kyverno policy use the canonical identity. Gatekeeper retains upstream text as inactive historical material. | No | INFO | Keep attribution/history references distinct from runtime trust references. | Live WIF provider describe; identity-consistency test; policy unit test. |
| CI-012 | Documentation digest accuracy | Documentation should quote the actual deployed immutable digest. | README, docs/codex/01-IMPLEMENTATION-PLAN.md, docs/codex/05-HANDOFF.md, and docs/my-validation/README.md now use the Helm/GAR digest. `docs/codex/03-VALIDATION.md` remains user-owned working-tree data and was deliberately not overwritten. | No — fixed where safe | LOW (fixed) | Corrected safe documentation values without changing the Helm pin. | Compare documentation with GAR describe and values.yaml. |

## Severity rationale

- No CRITICAL gap was found. PRs cannot reach WIF or production signing, the
  deployed artifact is digest-pinned, and Kyverno enforces signature, SBOM,
  provenance, Rekor, and digest checks at admission.
- CI-001 was HIGH because Verify is a stated security boundary and must not
  present a successful result while merely displaying an unexpected provenance
  payload. It is now closed and validated on main.
- CI-002 was HIGH because repository-only WIF scoping combined with a
  branch-selectable manual run expanded trusted cloud authority beyond intended
  main code. It is now closed and validated on main.
- CI-003 and CI-004 are MEDIUM because they weaken defense-in-depth and merge
  enforcement, respectively, without creating an observed PR-to-production
  credential bypass.

## Ordered implementation plan

1. Completed: CI-001 and CI-002 were implemented in an additive workflow
   hardening commit and validated by PR #2 plus main run `32638968765`.
2. Completed: local actionlint, Terraform, Helm, policy, and identity checks
   passed; the real PR passed Semgrep, Trivy, policy tests, and PR Image Scan
   while privileged jobs stayed skipped.
3. Completed: safe documentation values for CI-012 were corrected. Do not
   overwrite the user-modified `docs/codex/03-VALIDATION.md`; reconcile its
   captured evidence deliberately.
4. Stop for explicit approval before CI-004 branch-protection changes.
5. Treat CI-003 as a follow-up hardening project: it needs a reviewed scanner
   baseline and does not justify a blind blocking scan today.
