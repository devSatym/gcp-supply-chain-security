# supply-chain-security

A production-grade software supply chain security pipeline built on GitHub Actions, Sigstore, and Kubernetes admission control. Every image that reaches the cluster has been scanned, signed, attest[...]

Two independent enforcement engines are implemented and documented in this repo: **Kyverno** (verifies signatures/attestations natively) and **Gatekeeper + Ratify** (Gatekeeper delegates verificati[...]

## What This Project Does

Every push to `main` triggers a pipeline that:

1. Builds a multi-stage Docker image from a pinned Debian Bookworm base
2. Scans the image for critical vulnerabilities with Trivy
3. Signs the image digest with Cosign keyless signing (no private keys stored anywhere)
4. Generates an SPDX SBOM with Syft and attaches it as a Cosign attestation
5. Generates a SLSA provenance predicate and attaches it as a Cosign attestation
6. Verifies all three attestations before the pipeline completes
7. Blocks any unsigned or unattested image from running in Kubernetes, enforced at admission time

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
       -- push to Google Artifact Registry by SHA tag only (no :latest)
            -- Registry: europe-west1-docker.pkg.dev/<project>/supply-chain-security/supply-chain-demo
            -- Auth: Workload Identity Federation (OIDC token exchange, no static keys)
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
Kubernetes admission (Kyverno ClusterPolicy, or Gatekeeper + Ratify -- see below)
  -- valid Cosign keyless signature (verifyDigest / digest-pinned)
  -- valid SBOM attestation
  -- valid SLSA provenance attestation
       -- Conditions: entryPoint, builder ID, source repo URI
  [Pod blocked if any check fails]
```

No private keys are stored anywhere in the CI pipeline. The signing identity is derived from the GitHub Actions OIDC token and pinned to the Sigstore public transparency log (Rekor). Certificate l[...]

**What this proves, and what it doesn't.** Everything above establishes that an image was built, signed, and attested by an unmodified run of this repo's CI against a specific commit on `main` -- [...]

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
│   ├── CODEOWNERS               # Required reviewers for trust-chain-affecting paths
│   ├── dependabot.yml           # Weekly SHA-pin updates for Actions, pip, and Docker
│   ├── workflows/
│   │   ├── pr-check.yml         # Triggered on pull_request -- scan + policy tests only
│   │   ├── deploy.yml           # Triggered on push to main -- build + sign + verify
│   │   ├── build-push.yml       # Reusable: build, push, Trivy image scan
│   │   ├── sign-attest.yml      # Reusable: Cosign sign, Syft SBOM, SLSA provenance
│   │   ├── sbom-vex.yml         # Reusable: SBOM + VEX generation, non-blocking
│   │   ├── security-scan.yml    # Reusable: Semgrep SAST, Trivy filesystem
│   │   └── verify.yml           # Reusable: verify signature + attestations
│   └── actions/
│       ├── gcp-auth/            # Composite: GCP Workload Identity Federation + GAR login
│       ├── docker-login/        # Composite: Docker Hub login (legacy, kept for reference)
│       ├── setup-cosign/        # Composite: install Cosign
│       └── setup-syft/          # Composite: install Syft
├── policy/
│   ├── kyverno/
│   │   └── block-unsigned-images.yaml     # ClusterPolicy: 3 rules, Enforce mode
│   ├── gatekeeper/
│   │   ├── constraint-template.yaml       # OPA Rego, calls Ratify via external_data
│   │   ├── constraint.yaml                # K8sRequireSignedImages, namespace scope
│   │   ├── store-oras.yaml                # Ratify Store CRD (ORAS, cosign-enabled, k8Secrets auth)
│   │   └── verifier-cosign.yaml           # Ratify Verifier CRD (keyless trust policy)
│   ├── test-manifests/                    # Shared test Pods, used by both engines
│   │   ├── test-mixed-containers.yaml     # Test: signed main container + unsigned initContainer
│   │   └── test-init-unsigned.yaml        # Test: unsigned initContainer only
│   └── tests/                             # Policy unit tests, run in pr-check.yml
│       ├── check-identity-consistency.sh  # Cross-file identity string consistency check
│       ├── test_jmespath_conditions.py    # Kyverno Rule 3 JMESPath evaluation against real predicate
│       └── fixtures/
│           └── provenance-predicate.json  # Real captured SLSA provenance predicate for test fixtures
├── argocd/
│   ├── supply-chain-demo-app.yaml         # Happy-path ArgoCD Application (automated sync)
│   └── supply-chain-test-negative-app.yaml # Negative-test Application (manual sync only)
├── k8s/
│   └── helm/
│       └── supply-chain-demo/             # Helm chart for the demo application
├── terraform/
│   └── main.tf                            # GitHub branch protection ruleset (GitHub provider)
└── docs/
    ├── decisions/
    │   └── ratify-gcp-auth-tradeoff.md    # ADR: why Ratify uses a static JSON key for GAR auth
    ├── runbooks/
    │   └── troubleshooting-gatekeeper-kyverno.md  # Operational runbook: 13 real failure modes with fixes
    └── evidence/
        ├── deny-stage-violations.yaml     # Live Constraint status during deny-stage testing
        ├── init-container-gap-fix.md      # Before/after: the initContainer bypass bug
        ├── unsigned-rejected.txt          # Gatekeeper: unsigned image blocked
        ├── tampered-rejected.txt          # Gatekeeper: tampered signature blocked
        ├── mixed-containers-rejected.txt  # Gatekeeper: mixed container pod blocked
        ├── init-container-rejected.txt    # Gatekeeper: unsigned initContainer blocked
        ├── excluded-namespace-allowed.txt # Proof excluded namespaces bypass enforcement
        ├── kyverno-signed-admitted.txt    # Kyverno: correctly signed image admitted
        ├── kyverno-unsigned-rejected.txt  # Kyverno: unsigned image blocked
        ├── kyverno-tampered-rejected.txt  # Kyverno: tampered signature blocked
        ├── kyverno-mixed-containers-rejected.txt  # Kyverno: mixed container pod blocked
        └── kyverno-init-container-rejected.txt    # Kyverno: unsigned initContainer blocked
```

---

## Pipeline Design

### Registry: Google Artifact Registry via Workload Identity Federation

Images are stored in Google Artifact Registry (GAR), not Docker Hub. Authentication from GitHub Actions to GCP uses Workload Identity Federation -- no service account JSON keys are stored as GitH[...]

```
GitHub Actions OIDC token
       |
       v
GCP STS (token exchange)
       |
       v
Short-lived GCP access token
       |
       v
GAR push (supply-chain-ci@... SA, roles/artifactregistry.writer, repo-scoped)
```

The WIF pool (`github-pool`) and provider (`github-provider`) are scoped to this repo via an `attribute.repository` condition -- tokens from other repos in the same org cannot exchange for creden[...]

The reusable composite action at `.github/actions/gcp-auth/action.yml` wraps `google-github-actions/auth` and `gcloud auth configure-docker`. All workflows that need GAR access call this action r[...]

**Required repository variables** (not secrets -- these aren't sensitive):
- `GCP_WORKLOAD_IDENTITY_PROVIDER` -- the full WIF provider resource name
- `GCP_SA_EMAIL` -- `supply-chain-ci@<project>.iam.gserviceaccount.com`

### PR gate (pr-check.yml)

Runs on every pull request targeting `main`. No build, no push. Fast feedback on code quality and vulnerabilities before anything is merged.

- Semgrep scans source code, GitHub Actions workflows, Dockerfile, and Kubernetes manifests using `--config auto`
- Trivy scans the filesystem for dependency CVEs, secrets, and misconfigurations
- Both upload SARIF to the GitHub Security tab
- Either finding blocks the merge
- Test manifests under `policy/gatekeeper/` carry an explicit `securityContext` (`allowPrivilegeEscalation: false`, `runAsNonRoot: true`) specifically to keep this gate clean -- these pods exist [...]

### Deploy pipeline (deploy.yml)

Runs on push to `main` only. Trusts that the PR gate already passed.

Three reusable workflows called in sequence: `build-push` -> `sign-attest` -> `verify`. Each job depends on the previous via `needs:`. The image digest flows from `build-push` outputs through to [...]

### Why this separation matters

Signing happens only on `main`. No signed images are produced from feature branches. Both enforcement engines' identity checks (`sign-attest.yml@refs/heads/main`) are meaningful because they map [...]

### Trigger scoping

Both `deploy.yml` and `pr-check.yml` are path-filtered rather than running on every push or PR:

- `deploy.yml` triggers only on changes to `app/**`, `Dockerfile`, or `.dockerignore` -- a README edit or a policy YAML tweak alone does not rebuild, re-sign, or re-push an image. `workflow_dispa[...]
- `pr-check.yml` triggers on the same application paths, plus `.github/workflows/**` and `.github/actions/**` -- changes to CI itself are scanned before merge, since a compromised or misconfigure[...]

This keeps the pipeline from re-signing and re-pushing an image on every unrelated commit (docs, policy YAML, evidence files), while still gating anything that touches the build, the app, or the [...]

### SBOM + VEX generation (non-blocking)

`sbom-vex.yml` runs in parallel with `sign-attest` rather than gating it. This is intentional: SBOM/VEX generation and triage is valuable but shouldn't block a deploy if it's slow or transiently [...]

---

## Vulnerability Management

Trivy runs twice per deploy:

- **Pre-build (security-scan.yml):** filesystem scan on the source repo -- catches dependency CVEs before the image is built
- **Post-push (build-push.yml):** image scan on the pushed digest -- catches base image CVEs that only appear after the image is assembled

Critical CVEs with no available fix are suppressed in `.trivyignore` with documented justification for each entry. Each suppression explains why the vulnerable code path is unreachable or why no [...]

### VEX (planned enforcement layer, currently triage-only)

SBOM + vulnerability scanning generates a large number of findings, many of them false positives or non-applicable in this deployment's context. VEX (Vulnerability Exploitability eXchange) statem[...]

- **Not Affected** -- the vulnerable function is not called in this codebase
- **Affected** -- impacted, mitigation in place
- **Fixed** -- resolved in the current version
- **Under Investigation** -- triage in progress

VEX is currently used as documentation to justify `.trivyignore` suppressions, not yet wired into admission enforcement. The natural next step is attaching VEX documents (OpenVEX or CSAF format) [...]

---

## Enforcement, Option A: Kyverno

The `block-unsigned-images` ClusterPolicy runs in `Enforce` mode and applies to all namespaces except `kube-system`, `kyverno`, `argocd`, `crossplane-system`, and `cert-manager`.

Three rules must all pass before a Pod is admitted:

**Rule 1 -- verify-image-signature**
Verifies a valid Cosign keyless signature exists in Rekor for the image digest. Checks certificate subject and OIDC issuer. `verifyDigest: true` prevents tag substitution attacks.

**Rule 2 -- verify-sbom-attestation**
Verifies a Cosign attestation of type `spdxjson` exists and was signed by the same identity. `verifyDigest: true` enforced.

**Rule 3 -- verify-provenance-attestation**
Verifies a Cosign attestation of type `slsaprovenance` exists and validates three conditions:

- `invocation.configSource.entryPoint` matches `.github/workflows/sign-attest.yml`
- `builder.id` matches `https://github.com/actions/runner`
- `invocation.configSource.uri` matches `git+https://github.com/musaumakau/supply-chain-security@refs/heads/main`

The third condition is the critical one -- it prevents provenance generated from a fork or a different repository from being accepted.

**Important note on condition keys:** Kyverno decodes the attestation and scopes JMESPath evaluation directly to the predicate body. Condition keys should reference `{{ invocation.configSource.en[...]

**`maxContextSize`:** Kyverno's default context size limit (2Mi) is too small for a combined signature + SBOM + provenance attestation payload (real-world size for this image: ~5.7MB combined, be[...]

```bash
helm upgrade kyverno kyverno/kyverno \
  --namespace kyverno \
  --reuse-values \
  --set config.maxContextSize=8Mi
```

Do not patch the ConfigMap directly -- it gets silently reverted on the next `helm upgrade`.

---

## Enforcement, Option B: Gatekeeper + Ratify

Gatekeeper does not verify signatures itself. It calls out to **Ratify** via the `external_data` Rego built-in at admission time; Ratify performs the actual registry lookup and Cosign verificatio[...]

### Chain of resources, in dependency order

1. **`Store`** (`store-oras.yaml`) -- tells Ratify how to fetch signature/attestation artifacts from the registry (ORAS store, `cosignEnabled: true`, `k8Secrets` authProvider pointing at `ratify-[...]
2. **`Verifier`** (`verifier-cosign.yaml`) -- defines the trust policy: which registry scopes to check, and the expected keyless certificate identity + OIDC issuer
3. **`ConstraintTemplate`** (`constraint-template.yaml`) -- the Rego that calls Ratify's external data provider and turns a failed verification into a Gatekeeper violation
4. **`Constraint`** (`constraint.yaml`) -- binds the template to a scope (`Pod`, all namespaces except system/platform namespaces) and sets the enforcement stage

### GAR authentication for Ratify

Ratify needs read access to GAR to pull Cosign signatures and attestations stored alongside images. Unlike the CI pipeline (which uses Workload Identity Federation) and Kyverno (which uses GKE Wo[...]

The `k8Secrets` provider reads a `kubernetes.io/dockerconfigjson` Secret at verification time -- but Ratify hardcodes a 12-hour credential TTL (`const secretTimeout = time.Hour * 12` in `pkg/comm[...]

The only reliable option is a **long-lived GCP service account JSON key**, scoped minimally to `roles/artifactregistry.reader` on the single `supply-chain-security` repository. This is a delibera[...]

The key is stored as a `kubernetes.io/dockerconfigjson` Secret (`ratify-gar-regcred`) in `gatekeeper-system`, managed via Terraform (see `gcp-infrastructure-modules` repo). **Rotate every 90 days[...]

### Installing Gatekeeper

```bash
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo update

helm install gatekeeper gatekeeper/gatekeeper \
  --namespace gatekeeper-system \
  --create-namespace \
  --set enableExternalData=true \
  --set validatingWebhookTimeoutSeconds=5 \
  --set mutatingWebhookTimeoutSeconds=2 \
  --set externaldataProviderResponseCacheTTL=10s
```

### Installing Ratify

```bash
helm repo add ratify https://ratify-project.github.io/ratify
helm repo update

helm install ratify ratify/ratify --atomic \
  --namespace gatekeeper-system \
  --set featureFlags.RATIFY_CERT_ROTATION=true \
  --set oras.authProviders.k8secretsEnabled=true
```

`RATIFY_CERT_ROTATION=true` is required -- without it, the chart expects you to supply your own TLS certificate for Ratify's webhook server, which is unnecessary overhead for this setup.

`oras.authProviders.k8secretsEnabled=true` enables the `k8Secrets` auth provider in Ratify's ORAS store so it can read the GAR credentials Secret.

### Creating the GAR credentials Secret

After running `terraform apply` in `gcp-infrastructure-modules/environments/prod/`:

```bash
# Extract the key from Terraform state and create the k8s Secret
./create-ratify-secret.sh
```

Do not commit the JSON key or the rendered Secret manifest to git. The script handles extraction from Terraform state and idempotent Secret creation via `--dry-run=client | kubectl apply`.

### Disable the Gatekeeper mutating webhook

The Gatekeeper Helm chart installs a mutating webhook (`gatekeeper-mutating-webhook-configuration`) in addition to the validating webhook. The mutating webhook calls Ratify's `/ratify/gatekeeper/[...]

Since this repo uses digest-pinned images (no tag resolution needed), the mutating webhook provides no benefit and should be deleted:

```bash
kubectl delete mutatingwebhookconfiguration gatekeeper-mutating-webhook-configuration
```

The validating webhook (`gatekeeper-validating-webhook-configuration`) is unaffected and continues to enforce the policy.

### Applying the CRDs

Order matters -- `Store` before `Verifier`, and the `ConstraintTemplate` must be established before its generated CRD can accept a `Constraint`:

```bash
kubectl apply -f policy/gatekeeper/store-oras.yaml
kubectl apply -f policy/gatekeeper/verifier-cosign.yaml

kubectl apply -f policy/gatekeeper/constraint-template.yaml
kubectl wait --for=condition=established \
  crd/k8srequiresignedimages.constraints.gatekeeper.sh --timeout=30s
kubectl apply -f policy/gatekeeper/constraint.yaml
```

Confirm both Ratify resources report healthy before testing:

```bash
kubectl get store,verifier -n gatekeeper-system
# both should show ISSUCCESS: true
```

If `verifier-cosign` shows `CONFIG_INVALID: 'key' and 'rekorURL' are part of Cosign legacy configuration`, the Helm chart injects a stale `key:` field into the on-cluster object. Remove it:

```bash
kubectl patch verifier verifier-cosign \
  --type=json \
  -p='[{"op": "remove", "path": "/spec/parameters/key"}]'
```

### Rollout stages

`enforcementAction` supports a staged rollout, each stage was independently tested against real signed, unsigned, and tampered images:

- **`dryrun`** -- observes only, records violations in `.status.violations`, blocks nothing
- **`warn`** -- pod is still created, but the admission response carries a visible warning
- **`deny`** -- pod creation is rejected outright at admission time

### Webhook failure policy -- do this before testing enforcement

Gatekeeper's Helm chart defaults `validatingWebhookFailurePolicy` to `Ignore`. That means if the admission webhook's call to Ratify doesn't return within the timeout window, the request is **admi[...]

Set both the timeout and the failure policy explicitly before relying on `deny` mode:

```bash
helm upgrade gatekeeper gatekeeper/gatekeeper \
  --namespace gatekeeper-system \
  --reuse-values \
  --set validatingWebhookTimeoutSeconds=10 \
  --set validatingWebhookFailurePolicy=Fail
```

Confirm it landed:
```bash
kubectl get validatingwebhookconfigurations gatekeeper-validating-webhook-configuration \
  -o jsonpath='{.webhooks[0].failurePolicy} {.webhooks[0].timeoutSeconds}'
# should print: Fail 10
```

Note: the Helm value is `validatingWebhookFailurePolicy`, not `failurePolicy` -- the latter doesn't exist in this chart and is silently ignored with no error, which makes it easy to believe this [...]

---

## Test Evidence

Every claim above is backed by a real command run against a live GKE cluster (`prod-cluster`, `europe-west1`), not just policy YAML that's assumed to work. Raw output lives in `docs/evidence/`.

### Gatekeeper + Ratify

| Test case | Expected result | Verified |
|---|---|---|
| Signed image via ArgoCD (digest-pinned) | Admitted, `Synced`/`Healthy` | Yes |
| Unsigned image via `kubectl run` | Blocked at admission | Yes -- `[require-signed-images] image '...' failed Cosign signature verification` |
| Signed image still admitted after flipping to `deny` mode | Admitted | Yes -- ArgoCD app remains `Synced`/`Healthy` |
| Pod with signed main container + unsigned `initContainer` | Blocked, unsigned init container called out | Yes -- only the `unsigned-test` image appears in the rejection |

### Kyverno

| Test case | Expected result | Verified |
|---|---|---|
| Signed image via ArgoCD (digest-pinned) | Admitted, `Synced`/`Healthy` | Yes -- `docs/evidence/kyverno-signed-admitted.txt` |
| Unsigned image via `kubectl apply` | Blocked | Yes -- `docs/evidence/kyverno-unsigned-rejected-gke.txt` |
| Unsigned image via ArgoCD (negative-test Application) | `SyncFailed` | Yes |
| Tampered signature | Blocked | Yes -- `docs/evidence/kyverno-tampered-rejected.txt`. The `tampered` tag carries a real, valid signature from a different workflow identity (`image-sign-verify.ym[...]
| Pod with signed main container + unsigned `initContainer` | Blocked, init container called out | Yes -- `docs/evidence/kyverno-mixed-containers-rejected-gke.txt` |

---

## Kyverno Bugs Found During Live Testing

The Kyverno ClusterPolicy shipped for a while with real bugs that had never been exercised against a live cluster -- it looked correct on paper and blocked every image unconditionally in practice[...]

**1. Provenance rule used the wrong JMESPath scope and the wrong expected value.** The condition read `{{ predicate.invocation.configSource.entryPoint }}` and expected `.github/workflows/deploy.y[...]

**2. `sign-attest.yml` hardcoded its own entrypoint as a string literal.** Fixed by deriving it at runtime from the OIDC token's `job_workflow_ref` claim instead. Note `github.workflow_ref` (the [...]

**3. Every rule's `imageReferences` listed both `index.docker.io/5936/*` and `docker.io/5936/*`.** These aren't two registries -- `docker.io` always resolves to `index.docker.io`, so a single ima[...]

**4. Kyverno's `maxContextSize` (default 2Mi) was too small for a real SBOM.** Real combined attestation size for this image: ~5.7MB (cumulative across all `verifyImages` rules in one admission r[...]

None of these four were caught by code review alone -- they were only found by actually running the test cases against a live cluster and reading the real error messages.

---

## Troubleshooting

Real problems hit standing this up, kept here so the next debugging session doesn't start from zero. Full detail in `docs/evidence/troubleshooting-notes.md`.

1. **Ratify Helm install fails: "must provide a TLS certificate"**
   Fix: `--set featureFlags.RATIFY_CERT_ROTATION=true`.

2. **`Verifier` stuck at `CONFIG_INVALID: 'key' and 'rekorURL' are part of Cosign legacy configuration`**
   The Helm chart injects a default `key: /usr/local/ratify-certs/cosign/cosign.pub` field into the `verifier-cosign` object. `kubectl apply` merges rather than replaces, so the stale field persi[...]
   ```bash
   kubectl patch verifier verifier-cosign \
     --type=json \
     -p='[{"op": "remove", "path": "/spec/parameters/key"}]'
   ```

3. **Gatekeeper mutating webhook blocks every admission with 403 before the validating webhook runs**
   The `ratify-mutation-provider` calls Ratify's `/mutate` endpoint to resolve image tags to digests. This path does not use the Store CRD's `k8Secrets` authProvider and hits GAR unauthenticated.[...]
   ```bash
   kubectl delete mutatingwebhookconfiguration gatekeeper-mutating-webhook-configuration
   ```

4. **Ratify auth fails (403) even after creating `ratify-gar-regcred` and restarting the pod**
   The Secret was probably created before the `gatekeeper-system` namespace existed (e.g. before Gatekeeper was installed), and namespace deletion during reinstall deleted it silently. Verify:
   ```bash
   kubectl get secret ratify-gar-regcred -n gatekeeper-system
   ```
   If not found, re-run `create-ratify-secret.sh` from `gcp-infrastructure-modules/environments/prod/`.

5. **Correctly signed image still rejected after creating the Secret -- but only in the audit loop, not at admission**
   Ratify's credential cache TTL is hardcoded at 12 hours (`const secretTimeout = time.Hour * 12`). A pod restart forces a fresh credential load; a Secret update alone does not:
   ```bash
   kubectl rollout restart deployment/ratify -n gatekeeper-system
   ```

6. **`Verifier` stuck at `CONFIG_INVALID: the verificationCertStores configuration is invalid`**
   This is `verifier-notation`, a Helm default that requires a cert store you haven't configured. It does not affect Cosign verification. Ignore it or delete the Notation verifier if the noise is[...]

7. **`Constraint` stuck at `CONFIG_INVALID` even after fixing YAML on disk**
   `kubectl apply` performs a two-way merge -- stale fields from an earlier, broken version of the resource persist even when the file no longer contains them. Fix: `kubectl delete` then `kubectl[...]

8. **Cosign trust policy field is `scopes`, not `registryScopes`**
   `registryScopes` is the Notation verifier's field name. Using it on a Cosign `Verifier` produces `CONFIG_INVALID: scopes parameter is required`.

9. **Gatekeeper reports 0 violations even when Ratify is correctly rejecting images**
   Ratify surfaces per-image verification failures under `remote_data.responses[].isSuccess`, not `remote_data.errors` (that field is reserved for system-level failures like an unreachable regist[...]

10. **Correctly signed image still rejected: "none of the expected identities matched"**
    The `Verifier`'s `certificateIdentity` must exactly match the workflow file that actually produced the signature. A typo or a stale reference to a renamed workflow file causes real, correctly[...]

11. **An unsigned/mixed/tampered test pod is created successfully even though `enforcementAction: deny` is set and `totalViolations` correctly shows it as a violation**
    This is the Gatekeeper Helm chart's webhook `failurePolicy` defaulting to `Ignore`. When the admission webhook's call to Ratify doesn't return within `validatingWebhookTimeoutSeconds`, Gateke[...]
    ```bash
    helm upgrade gatekeeper gatekeeper/gatekeeper \
      --namespace gatekeeper-system \
      --reuse-values \
      --set validatingWebhookTimeoutSeconds=10 \
      --set validatingWebhookFailurePolicy=Fail
    ```
    Confirm: `kubectl get validatingwebhookconfigurations gatekeeper-validating-webhook-configuration -o jsonpath='{.webhooks[0].failurePolicy} {.webhooks[0].timeoutSeconds}'` should print `Fail [...]

12. **Kyverno webhook times out under `kubectl run`**
    Usually cluster resource pressure, not a policy bug -- check `kubectl get events -n kyverno` for `NodeNotReady` / liveness probe timeouts before assuming the policy itself is broken.

13. **`constraint-template.yaml` rejected with `unknown field "spec.crd.names"`**
    Indentation bug: `names:` must be nested under `spec:`, not a sibling of it:
    ```yaml
    # Correct
    crd:
      spec:
        names:
          kind: K8sRequireSignedImages
    ```

---

## Application Endpoints

The demo app exposes three endpoints:

| Endpoint | Response |
|---|---|
| `GET /` | `{"status": "ok", "service": "supply-chain-demo"}` |
| `GET /health` | `{"status": "healthy", "service": "supply-chain-demo"}` |
| `GET /info` | Git SHA, signed flag, service name |

Any running pod that reaches `/info` has already passed through admission control -- it proves the image was signed and attested before reaching the cluster.

---

## Required Configuration

### GitHub repository variables (not secrets)

| Variable | Value |
|---|---|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `projects/<number>/locations/global/workloadIdentityPools/github-pool/providers/github-provider` |
| `GCP_SA_EMAIL` | `supply-chain-ci@<project>.iam.gserviceaccount.com` |

### GCP infrastructure

The GCP infrastructure (VPC, GKE cluster, IAM, Workload Identity pool/provider, GAR repository) is managed in a separate repo (`gcp-infrastructure-modules`) via Terraform. Required resources:

- Workload Identity Federation pool + provider scoped to `musaumakau/supply-chain-security`
- `supply-chain-ci` GSA with `roles/artifactregistry.writer` (repo-scoped) for CI pushes
- `kyverno-gar-reader` GSA with `roles/artifactregistry.reader` (repo-scoped) bound to Kyverno KSAs via Workload Identity
- `ratify-gar-reader` GSA with `roles/artifactregistry.reader` (repo-scoped), long-lived JSON key stored as `ratify-gar-regcred` in `gatekeeper-system`

---

## Dependabot Cooldown

`dependabot.yml` sets `cooldown.default-days: 7` for both the `github-actions` and `pip` ecosystems. This delays Dependabot from opening a PR for a newly published release until it's been out for[...]

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
REGISTRY="europe-west1-docker.pkg.dev/<project>/supply-chain-security/supply-chain-demo"
DIGEST="sha256:<digest>"

# Verify signature
cosign verify \
  --certificate-identity-regexp="https://github.com/musaumakau/supply-chain-security/.github/workflows/sign-attest.yml@refs/heads/main" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  "${REGISTRY}@${DIGEST}"

# Verify SBOM attestation
cosign verify-attestation \
  --certificate-identity-regexp="https://github.com/musaumakau/supply-chain-security/.github/workflows/sign-attest.yml@refs/heads/main" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  --type spdxjson \
  "${REGISTRY}@${DIGEST}" \
  | jq '.payload | @base64d | fromjson | {predicateType, packageCount: (.predicate.packages | length)}'

# Verify provenance attestation
cosign verify-attestation \
  --certificate-identity-regexp="https://github.com/musaumakau/supply-chain-security/.github/workflows/sign-attest.yml@refs/heads/main" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  --type slsaprovenance \
  "${REGISTRY}@${DIGEST}" \
  | jq '.payload | @base64d | fromjson | {predicateType, builder: .predicate.builder.id, entryPoint: .predicate.invocation.configSource.entryPoint}'
```

---

## Deploying to a New Cluster

Start any new enforcement engine in an observe-only mode first, roll out per environment (dev, then staging, then production).

**Kyverno:**
```bash
# Set validationFailureAction to Audit first
kubectl apply -f policy/kyverno/block-unsigned-images.yaml
kubectl get clusterpolicy block-unsigned-images
kubectl get policyreport -A
# Once satisfied:
kubectl patch clusterpolicy block-unsigned-images \
  --type merge -p '{"spec":{"validationFailureAction":"Enforce"}}'
```

**Gatekeeper + Ratify:**
```bash
# Constraint starts in dryrun -- see enforcementAction in constraint.yaml
# Install Gatekeeper and Ratify (see above), create GAR Secret, delete mutating webhook
kubectl apply -f policy/gatekeeper/store-oras.yaml
kubectl apply -f policy/gatekeeper/verifier-cosign.yaml
kubectl apply -f policy/gatekeeper/constraint-template.yaml
kubectl apply -f policy/gatekeeper/constraint.yaml
# Verify dryrun violations look correct, then promote:
kubectl patch k8srequiresignedimages require-signed-images \
  --type=merge -p '{"spec":{"enforcementAction":"deny"}}'
```

---

## Tool Responsibilities

| Tool | Role |
|---|---|
| [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect) | Provides the identity token used for keyl[...]
| [GCP Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation) | Allows GitHub Actions to authenticate to GCP without storing service account keys |
| [Google Artifact Registry](https://cloud.google.com/artifact-registry) | Container registry for signed images and attestations |
| [Fulcio](https://docs.sigstore.dev/certificate_authority/overview/) | Sigstore CA -- issues short-lived signing certificates bound to the OIDC identity |
| [Cosign](https://docs.sigstore.dev/cosign/overview/) | Signs image digests, attaches SBOM and provenance attestations as OCI artifacts |
| [Rekor](https://docs.sigstore.dev/logging/overview/) | Public append-only transparency log -- stores signatures and certificates durably |
| [Syft](https://github.com/anchore/syft) | Generates SPDX JSON SBOMs from the container image |
| [Trivy](https://trivy.dev/) | Scans filesystem and container images for CVEs, secrets, and misconfigurations |
| [Semgrep](https://semgrep.dev/docs/) | SAST -- scans source, workflows, Dockerfile, and manifests for security issues |
| [Kyverno](https://kyverno.io/docs/) | Kubernetes admission controller -- verifies signatures/attestations natively (Option A) |
| [Gatekeeper](https://open-policy-agent.github.io/gatekeeper/website/docs/) | Kubernetes admission controller -- delegates verification to Ratify (Option B) |
| [Ratify](https://ratify.dev/docs/quickstarts/quickstart-manifest-validation) | Performs the actual Cosign verification on Gatekeeper's behalf via external data provider |
| [ArgoCD](https://argo-cd.readthedocs.io/) | GitOps deployment -- happy-path and negative-test Applications both live in `argocd/` |
| [Dependabot](https://docs.github.com/en/code-security/dependabot) | Keeps GitHub Actions SHA pins up to date weekly |

---

## Known Limitations

- The verify workflow runs in the same pipeline as sign. A fully separated architecture would trigger verification in a deployment pipeline, not immediately after signing. This is tracked as futu[...]
- Neither enforcement engine parses SBOM contents -- both confirm the SBOM was attached by the approved workflow, not that it contains specific packages.
- VEX statements currently inform `.trivyignore` suppressions but are not yet a verified admission-time attestation. Wiring VEX in as a fourth Cosign attestation type is the natural next step.
- Gatekeeper's status output reports `K8sNativeValidation engine is missing` for the `vap.k8s.io` enforcement point on clusters where that feature isn't enabled. This doesn't affect the webhook-b[...]
- **Ratify has no native GCP Workload Identity auth provider.** AWS IRSA, Azure Managed Identity/Workload Identity, and Alibaba RRSA are all supported; GCP is not (as of Ratify v1.15.x). The `k8S[...]
- **Fail-open is the Gatekeeper Helm chart default, and it is the wrong default for this project's threat model.** Out of the box, `validatingWebhookFailurePolicy` is `Ignore`. This repo runs wit[...]
- **Namespace exclusions are a full bypass, not a partial one.** Both `policy/kyverno/block-unsigned-images.yaml` and `policy/gatekeeper/constraint.yaml` exclude `kube-system`, `kyverno` (or `gat[...]
- Kyverno and Gatekeeper+Ratify are documented here as parallel options for comparison. Running both simultaneously against the same workloads in production is not recommended -- it adds operatio[...]
