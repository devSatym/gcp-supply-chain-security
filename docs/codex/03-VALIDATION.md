# Validation Matrix

| ID | Test | Expected | Actual | Status | Evidence |
| -- | ---- | -------- | ------ | ------ | -------- |
| V00 | Monorepo history integrity | Canonical merge exists, has two parents, and both are ancestors of `HEAD` | `6717e449…` has parents `cc1fa07…` and `c88320f…`; both ancestry checks pass | PASS | `00-REPO-AUDIT.md`, `docs/repository-merge.md` |
| V01 | Terraform fmt | All Terraform formatted | Recursive check passes after provider/Helm syntax adaptation | PASS | Local `terraform fmt -check -recursive infrastructure terraform` |
| V02 | Terraform validate | All deployable configurations valid | Full `infrastructure/environments/prod` root and transitive modules validate with backend disabled | PASS | Local `terraform init -backend=false -reconfigure` and `terraform validate -no-color` |
| V03 | Terraform plan | Explained plan | Not run | NOT RUN | — |
| V04 | Terraform apply | Infrastructure provisioned | Not run | NOT RUN | — |
| V05 | GKE nodes Ready | Nodes Ready | Not tested | NOT RUN | — |
| V06 | CI WIF authentication | Keyless OIDC succeeds | Not tested | NOT RUN | — |
| V07 | PR Semgrep | Scan passes | Not tested on personal PR | NOT RUN | — |
| V08 | PR Trivy | Scan passes | Not tested on personal PR | NOT RUN | — |
| V09 | Docker build | Build succeeds | Not run this audit | NOT RUN | — |
| V10 | GAR push | SHA-tagged artifact exists | Not tested | NOT RUN | — |
| V11 | Trivy image scan | Scan passes | Not tested | NOT RUN | — |
| V12 | Cosign signature | Personal keyless signature exists | Not tested | NOT RUN | — |
| V13 | SPDX SBOM | Personal SBOM generated | Not tested | NOT RUN | — |
| V14 | SLSA provenance | Personal provenance generated | Not tested | NOT RUN | — |
| V15 | Signature verification | Verification succeeds | Not tested | NOT RUN | — |
| V16 | SBOM verification | Verification succeeds | Not tested | NOT RUN | — |
| V17 | Provenance verification | Verification succeeds | Not tested | NOT RUN | — |
| V18 | Argo CD sync | Synced/Healthy | Not tested | NOT RUN | — |
| V19 | Trusted image admitted | Pod admitted | Existing upstream evidence retained; no personal test | NOT RUN | Historical evidence only |
| V20 | Unsigned image blocked | Pod denied | Existing upstream evidence retained; no personal test | NOT RUN | Historical evidence only |
| V21 | Invalid identity/provenance blocked | Pod denied | Existing upstream evidence retained; no personal test | NOT RUN | Historical evidence only |
| V22 | Mixed/init-container bypass blocked | Pod denied | Existing upstream evidence retained; no personal test | NOT RUN | Historical evidence only |
| V23 | Application reachable | Endpoints respond | Not tested | NOT RUN | — |
| V24 | Falco runtime event | Controlled event detected | Not tested | NOT RUN | — |
| V25 | External alert | Notification delivered | Not tested | NOT RUN | — |
| V26 | Final Terraform drift | No unexplained drift | Not run | NOT RUN | — |
| V27 | Application-side history reachable | Canonical application-side parent is an ancestor of `HEAD` | `cc1fa07…` is an ancestor | PASS | `00-REPO-AUDIT.md` |
| V28 | Infrastructure-side history reachable | Canonical infrastructure-side parent is an ancestor of `HEAD` | `c88320f…` is an ancestor | PASS | `00-REPO-AUDIT.md` |
| A01 | Helm chart rendering | Digest-pinned manifest renders | Passes; uses historical upstream digest | PASS (static only) | Local Helm render |
| A02 | Policy identity-path consistency | All consumers use signing workflow path | Passed; active Kyverno policy uses the canonical subject | PASS (static only) | `policy/tests/check-identity-consistency.sh` |
| A03 | Kyverno JMESPath conditions | Fixture matches policy conditions | Passed for canonical repository fixture | PASS (static only) | `policy/tests/test_jmespath_conditions.py` |
| A04 | Canonical repository identity | Active non-GCP runtime identities use `devSatym/gcp-supply-chain-security` | Argo repo URLs, Kyverno signer/provenance identity, fixture, OCI metadata, CODEOWNERS, Renovate, and ruleset Terraform updated; GAR values deliberately pending target-project confirmation | PASS (static only) | Git diff and local policy/YAML checks |
