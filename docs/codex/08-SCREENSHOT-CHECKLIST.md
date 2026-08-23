# Screenshot Checklist

Live command evidence is captured in `docs/my-validation/`. Add screenshots
only after removing unrelated account data, tokens, webhook URLs, and private
cluster metadata.

| File | Capture | Status |
| --- | --- | --- |
| `01-main-build-pipeline.png` | GitHub run `32630716371`: build, Trivy, sign, attest, verify | Ready |
| `02-gar-image-digest.png` | Primary GAR digest and separate Cosign metadata artifacts | Ready |
| `03-cosign-verification.png` | Subject, issuer, Rekor, and immutable digest verification | Ready |
| `04-sbom-provenance.png` | SPDX package count and SLSA builder/source checks | Ready |
| `05-gke-workloads.png` | Ready node, application replicas, Kyverno/Argo/Falco pods | Ready |
| `06-argocd-healthy.png` | Application `Synced/Healthy`, canonical repo/path | Ready |
| `07-trusted-admit.png` | Trusted digest server dry-run and live pods | Ready |
| `08-unsigned-blocked.png` | Kyverno denial with `no signatures found` | Ready |
| `09-invalid-trust-blocked.png` | Wrong signer and provenance-source mismatch denial | Ready |
| `10-init-bypass-blocked.png` | Mixed/init-container denial | Ready |
| `11-falco-runtime.png` | CRITICAL custom shell rule event with timestamp | Ready |
| `12-runtime-alert.png` | Discord notification | Pending webhook input |

The existing `docs/evidence/` files are historical upstream evidence and must
not be relabelled as personal screenshots.
