# Validation Matrix

| ID | Test | Actual result | Status |
| --- | --- | --- | --- |
| V00 | Canonical history | Merge `6717e449…d040c` has the required two parents; both ancestry checks pass | PASS |
| V01 | Terraform formatting | `terraform fmt -check -recursive infrastructure terraform` | PASS |
| V02 | Terraform validation | Prod root and transitive modules validate | PASS |
| V03 | Foundation plan/apply | Foundation targeted plan: 26 add; apply succeeded | PASS |
| V04 | Delivery plan/apply | GAR/WIF/CI targeted plan: 6 add; apply succeeded | PASS |
| V05 | GKE readiness | Nodes and system workloads reached Ready; autoscaler later reduced pool to one healthy node | PASS |
| V06 | GitHub WIF | Main deploy run built/pushed through WIF with no JSON key | PASS |
| V07 | PR Semgrep | No personal PR run captured | NOT RUN |
| V08 | PR Trivy | No personal PR run captured | NOT RUN |
| V09 | Docker build | Trixie image built locally and in GitHub Actions | PASS |
| V10 | GAR push | Primary digest and unsigned negative-test tag exist in target GAR | PASS |
| V11 | Trivy image scan | Remediated image passed high/critical exit-1 scan with narrow documented exception | PASS |
| V12 | Cosign signature | Keyless signature created for deployed digest | PASS |
| V13 | SPDX SBOM | SPDX attestation created and verified | PASS |
| V14 | SLSA provenance | SLSA v0.2 provenance created and verified | PASS |
| V15 | Signature verification | Subject, issuer, Rekor, and digest checks passed | PASS |
| V16 | SBOM verification | SPDX predicate and package payload verified | PASS |
| V17 | Provenance verification | Builder, entrypoint, source URI, and predicate verified | PASS |
| V18 | Argo CD sync | Application `Synced/Healthy`, revision `861ae77…` | PASS |
| V19 | Trusted image admission | Helm Deployment server dry-run and live pods admitted | PASS |
| V20 | Unsigned image blocked | Real `unsigned-test` GAR image denied: `no signatures found` | PASS |
| V21 | Invalid identity/provenance blocked | Test-only policy denied known signed image for wrong signer and source URI | PASS |
| V22 | Init-container bypass blocked | Mixed and unsigned-init fixtures denied | PASS |
| V23 | Application reachable | `/health` and `/info` returned healthy JSON from service | PASS |
| V24 | Falco runtime event | Controlled shell emitted CRITICAL custom-rule event | PASS |
| V25 | External alert | Discord path disabled; webhook not supplied | BLOCKED ON INPUT |
| V26 | Final Terraform drift | Plan output: `No changes` | PASS |
| A01 | Helm chart | Digest-pinned chart lint/render and server dry-run pass | PASS |
| A02 | Identity consistency | `check-identity-consistency.sh` passes | PASS |
| A03 | Kyverno JMESPath | Fixture test passes in isolated environment | PASS |

## Live run identifiers

```text
GitHub Deploy run: 32630716371 (success)
Deploy source commit: 9bf574ccb505cb4423472ffce716961000febb66
Final documentation commit: 861ae7728d1736f5bc63a6a272722345ac7fe1e0
Primary image digest: sha256:32a90d832fdf76794fa5477e42e1fdcec9eb6e0deee48ad466d1f7d9fc563
Unsigned test digest: sha256:18549c45e5d1d87804372cb8082cefbee1019b9c592d816d14817cc12472ca17
```

Historical files under `docs/evidence/` are not used to mark any row above
PASS. The PR rows require a real review branch before the GitHub ruleset is
activated remotely.
