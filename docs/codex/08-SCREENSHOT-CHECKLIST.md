# Screenshot Checklist

Live command evidence is captured in `docs/my-validation/`. Add screenshots
only after removing unrelated account data, tokens, webhook URLs, and private
cluster metadata. The PR and main screenshots below must show the GitHub URL
bar or another unambiguous repository/run identifier.

| File | Capture | Status |
| --- | --- | --- |
| `01-pr-security-gates.png` | Screenshot PR: PR title, target `main`, Detect relevant changes, Semgrep, Trivy, Policy Unit Tests, and PR Image Scan all PASS; no skipped checks | Ready to capture |
| `02-main-build-pipeline.png` | Main Deploy run `32638968765`: Build and Push, final Trivy, Sign and Attest, Verify, and the successful strict attestation checks | Ready to capture |
| `03-gar-image-digest.png` | Primary GAR digest and separate Cosign metadata artifacts | Ready to capture |
| `03b-live-deployment-digest.png` | Helm/Argo/GKE evidence that the live workload uses the digest-pinned image | Ready to capture |
| `04-cosign-verification.png` | Exact signer, issuer, Rekor, and immutable digest verification | Ready to capture |
| `05-sbom-provenance.png` | SPDX package count plus SLSA builder, entrypoint, source URI, and source commit checks | Ready to capture |
| `06-gke-workloads.png` | Ready node, application replicas, Kyverno/Argo/Falco pods | Ready to capture |
| `07-argocd-healthy.png` | Application `Synced/Healthy`, canonical repo/path, and desired digest | Ready to capture |
| `08-trusted-admit.png` | Trusted digest server dry-run and live pods | Ready to capture |
| `09-unsigned-blocked.png` | Kyverno denial with `no signatures found` | Ready to capture |
| `10-invalid-trust-blocked.png` | Wrong signer and provenance-source mismatch denial | Ready to capture |
| `11-init-bypass-blocked.png` | Mixed/init-container denial | Ready to capture |
| `12-falco-runtime.png` | CRITICAL custom shell rule event with timestamp | Ready to capture |
| `13-runtime-alert.png` | Discord notification | Pending webhook input |

The trusted Deploy workflow is not PR-triggered. A relevant PR therefore shows
only applicable unprivileged gates, all of which should pass. Main-only GAR,
signing, attestation, and verification remain unavailable to untrusted PR code.

The existing `docs/evidence/` files are historical upstream evidence and must
not be relabelled as personal screenshots.
