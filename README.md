# supply-chain-security

End-to-end container image signing and verification pipeline using Cosign keyless signing, Docker Hub, and Kubernetes admission control via Kyverno and OPA Gatekeeper.

## Overview

```
GitHub Actions CI
  --> build FastAPI image (multi-stage)
  --> push to Docker Hub (5936/supply-chain-demo)
  --> sign image digest with Cosign (keyless, Sigstore OIDC)
  --> verify signature in-pipeline (fast-fail gate)
       |
       v
EKS Admission Control
  --> Kyverno ClusterPolicy -- blocks unsigned images (primary)
  --> OPA Gatekeeper Constraint -- blocks unsigned images (secondary)
```

No private keys are stored anywhere. Signing identity is derived from the GitHub Actions OIDC token and anchored to the Sigstore public transparency log (Rekor).

## Repository Structure

```
.
├── app/
│   ├── main.py               # FastAPI application
│   └── requirements.txt      # Python dependencies
├── Dockerfile                # Multi-stage build
├── .github/workflows/
│   └── image-sign-verify.yml # CI: build, push, sign, verify
├── policy/
│   ├── kyverno/
│   │   └── block-unsigned-images.yaml
│   └── gatekeeper/
│       ├── constraint-template.yaml
│       └── constraint.yaml
└── README.md
```

## Application Endpoints

The demo app exposes three endpoints:

| Endpoint | Response |
|---|---|
| `GET /` | `{"status": "ok", "service": "supply-chain-demo"}` |
| `GET /health` | `{"status": "healthy", "service": "supply-chain-demo"}` |
| `GET /info` | version, image digest, signed flag |

The `/info` endpoint is the key one -- any running pod that reaches it has already passed through admission control, proving the image was signed.

## How Keyless Signing Works

1. The GitHub Actions job requests an OIDC token from GitHub's identity provider.
2. Cosign exchanges this token with Fulcio (Sigstore CA) for a short-lived signing certificate. The certificate embeds the workflow identity as the subject:
   ```
   Subject: https://github.com/musaumakau/supply-chain-security/.github/workflows/image-sign-verify.yml@refs/heads/main
   Issuer:  https://token.actions.githubusercontent.com
   ```
3. Cosign signs the image digest (not the tag) and uploads the signature + certificate to Rekor (public append-only transparency log).
4. The certificate expires after ~10 minutes -- the durable proof lives in Rekor.
5. Docker Hub stores the signature as an OCI artifact in the same repository under a digest-derived tag (`sha256-<digest>.sig`).

## Required GitHub Secrets

| Secret | Value |
|---|---|
| `DOCKERHUB_USERNAME` | `5936` |
| `DOCKERHUB_TOKEN` | Docker Hub access token -- create at hub.docker.com -> Account Settings -> Security |

## Docker Hub Setup

Create the repository before the first push:

```bash
# Via Docker Hub UI: hub.docker.com -> Repositories -> Create Repository
# Name: supply-chain-demo, Namespace: 5936
```

Or via API:

```bash
curl -s -X POST "https://hub.docker.com/v2/repositories/" \
  -H "Authorization: Bearer <your-token>" \
  -H "Content-Type: application/json" \
  -d '{"name": "supply-chain-demo", "namespace": "5936", "is_private": false}'
```

## Running Locally

```bash
# Build
docker build \
  --build-arg GIT_SHA=$(git rev-parse --short HEAD) \
  --build-arg IMAGE_DIGEST=local \
  -t supply-chain-demo:local .

# Run
docker run -p 8000:8000 supply-chain-demo:local

# Test
curl http://localhost:8000/
curl http://localhost:8000/health
curl http://localhost:8000/info
```

## Deploying the Policies to EKS

### Kyverno (primary)

```bash
# Start in Audit mode -- change validationFailureAction to Audit first
kubectl apply -f policy/kyverno/block-unsigned-images.yaml

# Check policy status
kubectl get clusterpolicy block-unsigned-images

# Watch for violations
kubectl get policyreport -A
```

### OPA Gatekeeper (secondary)

```bash
# Apply the ConstraintTemplate first and wait for it to be established
kubectl apply -f policy/gatekeeper/constraint-template.yaml
kubectl wait --for=condition=established \
  crd/k8srequiredsignedimages.constraints.gatekeeper.sh --timeout=60s

# Apply the Constraint
kubectl apply -f policy/gatekeeper/constraint.yaml

# Check audit violations
kubectl get k8srequiredsignedimages require-signed-images \
  -o jsonpath='{.status.violations}' | jq .
```

## Verifying a Signature Manually

```bash
cosign verify \
  --certificate-identity-regexp="https://github.com/musaumakau/supply-chain-security/.github/workflows/image-sign-verify.yml@refs/heads/main" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  5936/supply-chain-demo@sha256:<digest>
```

## Testing the Policy

Deploy an unsigned image -- should be blocked:

```bash
kubectl run unsigned-test --image=nginx:latest --namespace=default
# Expected: admission webhook denied the request
```

Deploy the signed image -- should be admitted:

```bash
kubectl run signed-test \
  --image=5936/supply-chain-demo@sha256:<digest> \
  --namespace=default
```

## Rollout Strategy

| Phase | Kyverno | Gatekeeper | Purpose |
|---|---|---|---|
| 1 -- Observe | `Audit` | `dryrun` | Baseline, no blocking |
| 2 -- Warn | `Audit` | `warn` | Surface violations to teams |
| 3 -- Enforce | `Enforce` | `deny` | Hard block on unsigned images |

Roll out per environment: dev first, staging, then production.

## Notes

- **Gatekeeper + Ratify:** Gatekeeper cannot call Rekor at admission time natively. It relies on [Ratify](https://github.com/ratify-project/ratify) as a mutating webhook to pre-verify and annotate pods. Without Ratify, Kyverno is the effective enforcement layer -- Gatekeeper is secondary.
- **Tag mutability:** `mutateDigest: true` in the Kyverno policy rewrites tag references to digest-pinned references at admission, preventing tag re-push attacks.
- **Private Rekor:** Keyless signing writes to the public Rekor log. If workflow identity is sensitive, consider a private Sigstore deployment or switch to KMS-based signing.
