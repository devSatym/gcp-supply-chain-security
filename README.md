# supply-chain-security

A production-grade software supply chain security pipeline built on GitHub Actions, Sigstore, and Kubernetes admission control. Every image that reaches the cluster has been scanned, signed, attested, and verified -- enforced at the admission layer by Kyverno.

## What This Project Does

Every push to `main` triggers a pipeline that:

1. Builds a multi-stage Docker image from a pinned Debian Bookworm base
2. Scans the image for critical vulnerabilities with Trivy
3. Signs the image digest with Cosign keyless signing (no private keys stored anywhere)
4. Generates an SPDX SBOM with Syft and attaches it as a Cosign attestation
5. Generates a SLSA provenance predicate and attaches it as a Cosign attestation
6. Verifies all three attestations before the pipeline completes
7. Blocks any unsigned or unattested image from running in Kubernetes via Kyverno

Every PR is gated by Semgrep SAST and Trivy filesystem scanning before any build happens.

---

## Trust Chain

```
Developer opens PR
       |
       v
pr-check.yml
  -- Semgrep SAST (workflows, Dockerfile, manifests, source)
  -- Trivy filesystem scan (deps, secrets, misconfigs)
       |
  [PR blocked if findings]
       |
       v
PR merged to main
       |
       v
deploy.yml
  -- build-push.yml
       -- docker buildx build (python:3.12-slim-bookworm, multi-stage)
       -- push to Docker Hub by SHA tag only (no :latest)
       -- Trivy image scan post-push (CRITICAL, exit 1)
       -- SARIF uploaded to GitHub Security tab
       |
  -- sign-attest.yml
       -- Cosign keyless sign via Sigstore OIDC
            -- GitHub Actions OIDC token -> Fulcio CA -> short-lived cert
            -- Cert subject: sign-attest.yml@refs/heads/main
            -- Signature + cert uploaded to Rekor transparency log
       -- Syft generates SPDX JSON SBOM
            -- Attached as Cosign OCI attestation (type: spdxjson)
            -- Uploaded as GitHub Actions artifact (90-day retention)
       -- SLSA provenance predicate generated
            -- Embedded: repo URI, commit SHA, workflow, ref, builder ID
            -- Attached as Cosign OCI attestation (type: slsaprovenance)
       |
  -- verify.yml
       -- cosign verify (signature + Rekor log)
       -- cosign verify-attestation (SBOM)
       -- cosign verify-attestation (provenance)
            -- Verifies: entryPoint, builder ID, source repo URI
       |
       v
Kubernetes admission (Kyverno ClusterPolicy)
  -- Rule 1: valid Cosign keyless signature (verifyDigest: true)
  -- Rule 2: valid SBOM attestation (verifyDigest: true)
  -- Rule 3: valid SLSA provenance (verifyDigest: true)
       -- Conditions: entryPoint, builder ID, source repo URI
  [Pod blocked if any rule fails]
```

No private keys are stored anywhere. The signing identity is derived from the GitHub Actions OIDC token and pinned to the Sigstore public transparency log (Rekor). Certificate lifetime is ~10 minutes -- the durable proof lives in Rekor.

---

## Repository Structure

```
.
├── app/
│   ├── main.py                  # FastAPI application (3 endpoints)
│   └── requirements.txt         # Pinned Python dependencies
├── Dockerfile                   # Multi-stage, non-root, Bookworm-pinned
├── .trivyignore                 # Documented CVE suppressions with justification
├── .github/
│   ├── dependabot.yml           # Weekly SHA-pin updates for Actions
│   ├── workflows/
│   │   ├── pr-check.yml         # Triggered on pull_request -- scan only
│   │   ├── deploy.yml           # Triggered on push to main -- build + sign + verify
│   │   ├── build-push.yml       # Reusable: build, push, Trivy image scan
│   │   ├── sign-attest.yml      # Reusable: Cosign sign, Syft SBOM, SLSA provenance
│   │   ├── security-scan.yml    # Reusable: Semgrep SAST, Trivy filesystem
│   │   └── verify.yml           # Reusable: verify signature + attestations
│   └── actions/
│       ├── docker-login/        # Composite: Docker Hub login
│       ├── setup-cosign/        # Composite: install Cosign
│       └── setup-syft/          # Composite: install Syft
└── policy/
    └── kyverno/
        └── block-unsigned-images.yaml  # ClusterPolicy: 3 rules, Enforce mode
```

---

## Pipeline Design

### PR gate (pr-check.yml)

Runs on every pull request targeting `main`. No build, no push. Fast feedback on code quality and vulnerabilities before anything is merged.

- Semgrep scans source code, GitHub Actions workflows, Dockerfile, and Kubernetes manifests using `--config auto`
- Trivy scans the filesystem for dependency CVEs, secrets, and misconfigurations
- Both upload SARIF to the GitHub Security tab
- Either finding blocks the merge

### Deploy pipeline (deploy.yml)

Runs on push to `main` only. Trusts that the PR gate already passed.

Three reusable workflows called in sequence: `build-push` -> `sign-attest` -> `verify`. Each job depends on the previous via `needs:`. The image digest flows from `build-push` outputs through to `sign-attest` and `verify` inputs -- no tag references, digest only.

### Why this separation matters

Signing happens only on `main`. No signed images are produced from feature branches. The Kyverno policy's `refs/heads/main` constraint is meaningful because it maps directly to the only trigger that produces signed artifacts.

---

## Vulnerability Management

Trivy runs twice per deploy:

- **Pre-build (security-scan.yml):** filesystem scan on the source repo -- catches dependency CVEs before the image is built
- **Post-push (build-push.yml):** image scan on the pushed digest -- catches base image CVEs that only appear after the image is assembled

Critical CVEs with no available fix are suppressed in `.trivyignore` with documented justification for each entry. Each suppression explains why the vulnerable code path is unreachable or why no fix exists upstream. This is intentional -- silent suppression without rationale is not acceptable in a production pipeline.

---

## Kyverno Policy

The `block-unsigned-images` ClusterPolicy runs in `Enforce` mode and applies to all namespaces except `kube-system`, `kyverno`, `argocd`, `crossplane-system`, and `cert-manager`.

Three rules must all pass before a Pod is admitted:

**Rule 1 -- verify-image-signature**
Verifies a valid Cosign keyless signature exists in Rekor for the image digest. Checks certificate subject and OIDC issuer. `verifyDigest: true` prevents tag substitution attacks.

**Rule 2 -- verify-sbom-attestation**
Verifies a Cosign attestation of type `spdxjson` exists and was signed by the same identity. `verifyDigest: true` enforced.

**Rule 3 -- verify-provenance-attestation**
Verifies a Cosign attestation of type `slsaprovenance` exists and validates three conditions:

- `entryPoint` matches `.github/workflows/sign-attest.yml`
- `builder.id` matches `https://github.com/actions/runner`
- `configSource.uri` matches `git+https://github.com/musaumakau/supply-chain-security@refs/heads/main`

The third condition is the critical one -- it prevents provenance generated from a fork or a different repository from being accepted.

---

## Application Endpoints

The demo app exposes three endpoints:

| Endpoint | Response |
|---|---|
| `GET /` | `{"status": "ok", "service": "supply-chain-demo"}` |
| `GET /health` | `{"status": "healthy", "service": "supply-chain-demo"}` |
| `GET /info` | Git SHA, signed flag, service name |

Any running pod that reaches `/info` has already passed through Kyverno admission control -- it proves the image was signed and attested before reaching the cluster.

---

## Required GitHub Secrets

| Secret | Description |
|---|---|
| `DOCKERHUB_USERNAME` | Docker Hub username (`5936`) |
| `DOCKERHUB_TOKEN` | Docker Hub access token -- create at hub.docker.com -> Account Settings -> Security |

---

## Running Locally

```bash
# Build
docker build \
  --build-arg GIT_SHA=$(git rev-parse --short HEAD) \
  -t supply-chain-demo:local .

# Run
docker run -p 8000:8000 supply-chain-demo:local

# Test
curl http://localhost:8000/
curl http://localhost:8000/health
curl http://localhost:8000/info
```

---

## Verifying a Signed Image Manually

```bash
# Verify signature
cosign verify \
  --certificate-identity-regexp="https://github.com/musaumakau/supply-chain-security/.github/workflows/sign-attest.yml@refs/heads/main" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  5936/supply-chain-demo@sha256:<digest>

# Verify SBOM attestation
cosign verify-attestation \
  --certificate-identity-regexp="https://github.com/musaumakau/supply-chain-security/.github/workflows/sign-attest.yml@refs/heads/main" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  --type spdxjson \
  5936/supply-chain-demo@sha256:<digest> \
  | jq '.payload | @base64d | fromjson | {predicateType, packageCount: (.predicate.packages | length)}'

# Verify provenance attestation
cosign verify-attestation \
  --certificate-identity-regexp="https://github.com/musaumakau/supply-chain-security/.github/workflows/sign-attest.yml@refs/heads/main" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  --type slsaprovenance \
  5936/supply-chain-demo@sha256:<digest> \
  | jq '.payload | @base64d | fromjson | {predicateType, builder: .predicate.builder.id, entryPoint: .predicate.invocation.configSource.entryPoint}'
```

---

## Deploying Kyverno Policies to EKS

```bash
# Start in Audit mode first -- change validationFailureAction to Audit in the policy
kubectl apply -f policy/kyverno/block-unsigned-images.yaml

# Check policy status
kubectl get clusterpolicy block-unsigned-images

# Watch for violations
kubectl get policyreport -A

# Once satisfied, switch to Enforce
kubectl patch clusterpolicy block-unsigned-images \
  --type merge \
  -p '{"spec":{"validationFailureAction":"Enforce"}}'
```

Roll out per environment: dev first, then staging, then production.

---

## Testing the Policy

## Testing the Policy

Deploy an image from your namespace that was never signed -- should be blocked:

```bash
# Tag and push an unsigned image into your namespace
docker pull nginx:latest
docker tag nginx:latest docker.io/5936/supply-chain-demo:unsigned-test
docker push docker.io/5936/supply-chain-demo:unsigned-test

# Attempt to run it -- all three Kyverno rules should fire
kubectl run unsigned-test \
  --image=5936/supply-chain-demo:unsigned-test \
  --namespace=default
# Expected:
# Error from server: admission webhook "mutate.kyverno.svc-fail" denied the request
# block-unsigned-images:
#   verify-image-signature: no signatures found
#   verify-sbom-attestation: no matching attestations
#   verify-provenance-attestation: no matching attestations
```

Note: third-party images like `nginx:latest` are not subject to this policy -- enforcement only applies to images under the `5936/*` namespace. This is intentional.

Deploy the signed image by digest -- should be admitted:

```bash
kubectl run signed-test \
  --image=5936/supply-chain-demo@sha256:<digest> \
  --namespace=default
```

---

## Tool Responsibilities

| Tool | Role |
|---|---|
| GitHub Actions OIDC | Provides the identity token used for keyless signing -- no secrets needed |
| Fulcio | Sigstore CA -- issues short-lived signing certificates bound to the OIDC identity |
| Cosign | Signs image digests, attaches SBOM and provenance attestations as OCI artifacts |
| Rekor | Public append-only transparency log -- stores signatures and certificates durably |
| Syft | Generates SPDX JSON SBOMs from the container image |
| Trivy | Scans filesystem and container images for CVEs, secrets, and misconfigurations |
| Semgrep | SAST -- scans source, workflows, Dockerfile, and manifests for security issues |
| Kyverno | Kubernetes admission controller -- enforces signature and attestation requirements |
| Dependabot | Keeps GitHub Actions SHA pins up to date weekly |

---

## Known Limitations

- The verify workflow runs in the same pipeline as sign. A fully separated architecture would trigger verification in a deployment pipeline, not immediately after signing. This is tracked as future work.
- Kyverno verifies attestation existence and identity but does not parse SBOM contents -- it confirms the SBOM was attached by the approved workflow, not that it contains specific packages.
- The pipeline targets Docker Hub. Migration to Amazon ECR with IRSA-based authentication is the recommended path for AWS production deployments.