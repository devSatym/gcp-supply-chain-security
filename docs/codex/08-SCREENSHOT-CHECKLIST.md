# Screenshot Checklist

Create `docs/my-validation/` only after tests have actually run. Existing `docs/evidence/` files are historical and must not be relabelled as personal evidence.

| File | Where / what must be visible | Why it matters | Hide |
| --- | --- | --- | --- |
| `01-pr-security-gates.png` | Personal PR checks: Semgrep, Trivy, policy tests | PR gate proof | Account email, unrelated tabs |
| `02-main-build-pipeline.png` | Successful main workflow graph | Build/sign/attest/verify chain | Tokens, IDs not needed |
| `03-gar-image-digest.png` | GAR package/version and immutable digest | Artifact identity | Project metadata if desired |
| `04-cosign-verification.png` | Signature verification subject and issuer | Trusted signer proof | Environment tokens |
| `05-sbom-provenance-verification.png` | SBOM and provenance verification output | Attestation proof | Full payloads containing unnecessary metadata |
| `06-gke-workloads.png` | Ready nodes and application pods | Healthy runtime | Internal endpoint/IPs if sensitive |
| `07-argocd-healthy.png` | Argo Application Synced/Healthy | GitOps proof | Session data |
| `08-trusted-image-admitted.png` | Kyverno-admitted trusted digest workload | Positive admission proof | Unnecessary cluster metadata |
| `09-unsigned-image-blocked.png` | Exact Kyverno denial for protected unsigned image | Negative signature proof | Credentials |
| `10-invalid-provenance-blocked.png` | Exact identity/provenance denial | Provenance guard proof | Credentials |
| `11-init-container-bypass-blocked.png` | Denial naming unsigned initContainer | Complete-container coverage | Credentials |
| `12-falco-runtime-detection.png` | Falco rule, priority, pod, timestamp | Runtime detection proof | Tokens, broad log context |
| `13-runtime-alert.png` | Received Discord alert and timestamp | End-to-end alert proof | Webhook URL, private channel members |
