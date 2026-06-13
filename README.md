# supply-chain-security

A production-grade software supply chain security pipeline built on GitHub Actions, Sigstore, and Kubernetes admission control. Every image that reaches the cluster has been scanned, signed, attested, and verified -- enforced at the admission layer.

Two independent enforcement engines are implemented and documented in this repo: **Kyverno** (verifies signatures/attestations natively) and **Gatekeeper + Ratify** (Gatekeeper delegates verification to Ratify via the external data provider pattern). They are not meant to run simultaneously in a real deployment -- pick one. This repo documents both because comparing the same policy across two engines is a useful exercise, and because the debugging process for each surfaced different, non-obvious failure modes worth recording.

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
Kubernetes admission (Kyverno ClusterPolicy, or Gatekeeper + Ratify -- see below)
  -- valid Cosign keyless signature (verifyDigest / digest-pinned)
  -- valid SBOM attestation
  -- valid SLSA provenance attestation
       -- Conditions: entryPoint, builder ID, source repo URI
  [Pod blocked if any check fails]
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
│   │   ├── sbom-vex.yml         # Reusable: SBOM + VEX generation, non-blocking
│   │   ├── security-scan.yml    # Reusable: Semgrep SAST, Trivy filesystem
│   │   └── verify.yml           # Reusable: verify signature + attestations
│   └── actions/
│       ├── docker-login/        # Composite: Docker Hub login
│       ├── setup-cosign/        # Composite: install Cosign
│       └── setup-syft/          # Composite: install Syft
├── policy/
│   ├── kyverno/
│   │   └── block-unsigned-images.yaml     # ClusterPolicy: 3 rules, Enforce mode
│   └── gatekeeper/
│       ├── constrainttemplate.yaml        # OPA Rego, calls Ratify via external_data
│       ├── constraint.yaml                # K8sRequireSignedImages, namespace scope
│       ├── store-oras.yaml                # Ratify Store CRD (ORAS, cosign-enabled)
│       ├── verifier-cosign.yaml           # Ratify Verifier CRD (keyless trust policy)
│       ├── test-mixed-containers.yaml     # Test: one signed + one unsigned container
│       └── test-init-unsigned.yaml        # Test: unsigned initContainer
└── docs/
    └── evidence/
        ├── deny-stage-violations.yaml     # Live Constraint status during deny-stage testing
        ├── unsigned-rejected.txt          # Raw admission rejection, unsigned image
        ├── tampered-rejected.txt          # Raw admission rejection, tampered signature
        ├── mixed-containers-rejected.txt  # Raw admission rejection, mixed containers
        ├── init-container-rejected.txt    # Raw admission rejection, unsigned init container
        ├── excluded-namespace-allowed.txt # Proof excluded namespaces bypass enforcement
        ├── init-container-gap-fix.md      # Before/after: the initContainer bypass bug
        └── troubleshooting-notes.md       # Every real bug hit standing up Gatekeeper+Ratify
```

---

## Pipeline Design

### PR gate (pr-check.yml)

Runs on every pull request targeting `main`. No build, no push. Fast feedback on code quality and vulnerabilities before anything is merged.

- Semgrep scans source code, GitHub Actions workflows, Dockerfile, and Kubernetes manifests using `--config auto`
- Trivy scans the filesystem for dependency CVEs, secrets, and misconfigurations
- Both upload SARIF to the GitHub Security tab
- Either finding blocks the merge
- Test manifests under `policy/gatekeeper/` carry an explicit `securityContext` (`allowPrivilegeEscalation: false`, `runAsNonRoot: true`) specifically to keep this gate clean -- these pods exist only to exercise admission control, but they're still subject to the same Semgrep rules as production manifests

### Deploy pipeline (deploy.yml)

Runs on push to `main` only. Trusts that the PR gate already passed.

Three reusable workflows called in sequence: `build-push` -> `sign-attest` -> `verify`. Each job depends on the previous via `needs:`. The image digest flows from `build-push` outputs through to `sign-attest` and `verify` inputs -- no tag references, digest only.

### Why this separation matters

Signing happens only on `main`. No signed images are produced from feature branches. Both enforcement engines' identity checks (`sign-attest.yml@refs/heads/main`) are meaningful because they map directly to the only trigger that produces signed artifacts.

### Trigger scoping

Both `deploy.yml` and `pr-check.yml` are path-filtered rather than running on every push or PR:

- `deploy.yml` triggers only on changes to `app/**`, `Dockerfile`, or `.dockerignore` -- a README edit or a policy YAML tweak alone does not rebuild, re-sign, or re-push an image. `workflow_dispatch` is also enabled for manual re-runs (for example, re-signing after a Sigstore outage, without needing a throwaway code change).
- `pr-check.yml` triggers on the same application paths, plus `.github/workflows/**` and `.github/actions/**` -- changes to CI itself are scanned before merge, since a compromised or misconfigured workflow file is as much a supply chain risk as compromised application code.

This keeps the pipeline from re-signing and re-pushing an image on every unrelated commit (docs, policy YAML, evidence files), while still gating anything that touches the build, the app, or the CI definitions themselves.

### SBOM + VEX generation (non-blocking)

`sbom-vex.yml` runs in parallel with `sign-attest` rather than gating it. This is intentional: SBOM/VEX generation and triage is valuable but shouldn't block a deploy if it's slow or transiently fails, whereas signing and attestation verification are hard gates. See [VEX](#vex-planned-enforcement-layer-currently-triage-only) below for what's currently enforced versus documented.

---

## Vulnerability Management

Trivy runs twice per deploy:

- **Pre-build (security-scan.yml):** filesystem scan on the source repo -- catches dependency CVEs before the image is built
- **Post-push (build-push.yml):** image scan on the pushed digest -- catches base image CVEs that only appear after the image is assembled

Critical CVEs with no available fix are suppressed in `.trivyignore` with documented justification for each entry. Each suppression explains why the vulnerable code path is unreachable or why no fix exists upstream. This is intentional -- silent suppression without rationale is not acceptable in a production pipeline.

### VEX (planned enforcement layer, currently triage-only)

SBOM + vulnerability scanning generates a large number of findings, many of them false positives or non-applicable in this deployment's context. VEX (Vulnerability Exploitability eXchange) statements add that context on top of the raw scan:

- **Not Affected** -- the vulnerable function is not called in this codebase
- **Affected** -- impacted, mitigation in place
- **Fixed** -- resolved in the current version
- **Under Investigation** -- triage in progress

VEX is currently used as documentation to justify `.trivyignore` suppressions, not yet wired into admission enforcement. The natural next step is attaching VEX documents (OpenVEX or CSAF format) as a fourth Cosign attestation type, verified the same way SBOM and provenance are today -- tracked as future work.

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

**Important note on condition keys:** Kyverno decodes the attestation and scopes JMESPath evaluation directly to the predicate body. Condition keys should reference `{{ invocation.configSource.entryPoint }}`, not `{{ predicate.invocation.configSource.entryPoint }}` -- there is no top-level `predicate` key to descend into once inside an attestation condition block. Writing it with the `predicate.` prefix produces `JMESPath query failed: Unknown key "predicate" in path` and silently blocks every pod, signed or not.

---

## Enforcement, Option B: Gatekeeper + Ratify

Gatekeeper does not verify signatures itself. It calls out to **Ratify** via the `external_data` Rego built-in at admission time; Ratify performs the actual registry lookup and Cosign verification, and returns a structured pass/fail result inline.

### Chain of resources, in dependency order

1. **`Store`** (`store-oras.yaml`) -- tells Ratify how to fetch signature/attestation artifacts from the registry (ORAS store, `cosignEnabled: true`)
2. **`Verifier`** (`verifier-cosign.yaml`) -- defines the trust policy: which registry scopes to check, and the expected keyless certificate identity + OIDC issuer
3. **`ConstraintTemplate`** (`constrainttemplate.yaml`) -- the Rego that calls Ratify's external data provider and turns a failed verification into a Gatekeeper violation
4. **`Constraint`** (`constraint.yaml`) -- binds the template to a scope (`Pod`, all namespaces except system/platform namespaces) and sets the enforcement stage

### Rollout stages

`enforcementAction` supports a staged rollout, each stage was independently tested against real signed, unsigned, and tampered images:

- **`dryrun`** -- observes only, records violations in `.status.violations`, blocks nothing
- **`warn`** -- pod is still created, but the admission response carries a visible warning
- **`deny`** -- pod creation is rejected outright at admission time

### Installing Ratify

```bash
helm repo add ratify https://notaryproject.github.io/ratify
helm repo update
helm install ratify ratify/ratify \
  --namespace gatekeeper-system \
  --set policy.useRego=true \
  --set featureFlags.RATIFY_CERT_ROTATION=true
```

`RATIFY_CERT_ROTATION=true` is required for local/test clusters -- without it, the chart expects you to supply your own TLS certificate for Ratify's webhook server via `--set-file provider.tls.crt=... provider.tls.key=...`, which is the right call for production but unnecessary overhead for a demo cluster.

### Applying the CRDs

Order matters -- `Store` before `Verifier`, and the `ConstraintTemplate` must be established before its generated CRD can accept a `Constraint`:

```bash
kubectl apply -f policy/gatekeeper/store-oras.yaml
kubectl apply -f policy/gatekeeper/verifier-cosign.yaml

kubectl apply -f policy/gatekeeper/constrainttemplate.yaml
kubectl wait --for=condition=established \
  crd/k8srequiresignedimages.constraints.gatekeeper.sh --timeout=30s
kubectl apply -f policy/gatekeeper/constraint.yaml
```

Confirm both Ratify resources report healthy before testing:

```bash
kubectl get stores.config.ratify.deislabs.io
kubectl get verifiers.config.ratify.deislabs.io
# both should show ISSUCCESS: true
```

### Webhook failure policy -- do this before testing enforcement

Gatekeeper's Helm chart defaults `validatingWebhookFailurePolicy` to `Ignore`. That means if the admission webhook's call to Ratify doesn't return within the timeout window (3 seconds by default), the request is **admitted**, not blocked -- a slow or momentarily unreachable verifier becomes a silent bypass. This is easy to miss because the background audit loop still correctly flags the resulting pod as a violation, so `totalViolations` looks right even while unsigned pods are actively getting created.

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

Note: the Helm value is `validatingWebhookFailurePolicy`, not `failurePolicy` -- the latter doesn't exist in this chart and is silently ignored with no error, which makes it easy to believe this is fixed when it isn't. See [Known Limitations](#known-limitations) for the availability tradeoff this introduces.

---

## Test Evidence

Every claim above is backed by a real command run against a live cluster, not just policy YAML that's assumed to work. Raw output lives in `docs/evidence/`.

| Test case | Expected result | Verified |
|---|---|---|
| Signed image (`latest`) | Admitted | Yes -- passes at all three stages |
| Unsigned image (`unsigned-test`) | Blocked | Yes -- `docs/evidence/unsigned-rejected.txt` |
| Tampered signature (`tampered`) | Blocked | Yes -- `docs/evidence/tampered-rejected.txt`, proves Ratify checks cryptographic validity, not just presence of a signature |
| Excluded namespace + unsigned image | Admitted (exclusion honored) | Yes -- `docs/evidence/excluded-namespace-allowed.txt` |
| Pod with one signed + one unsigned container | Blocked | Yes -- `docs/evidence/mixed-containers-rejected.txt`, confirms every container in a pod spec is checked, not just the first |
| Pod with unsigned `initContainer` | Blocked (after fix -- see below) | Yes -- `docs/evidence/init-container-rejected.txt` |

### A real gap found through edge-case testing: unsigned init containers

The first version of the Gatekeeper Rego only read `input.review.object.spec.containers`. An unsigned image placed in `initContainers` was never sent to Ratify for verification and passed admission cleanly -- a real bypass, since init containers run with full access to the pod's volumes and can execute arbitrary code before the verified main container ever starts.

Found and fixed by systematically testing beyond the happy path rather than assuming `containers[]` coverage was complete. Full before/after proof, including the exact rejected-then-blocked commands, is in `docs/evidence/init-container-gap-fix.md`. The fix extends the Rego to concatenate `containers`, `initContainers`, and `ephemeralContainers` before building the image list sent to Ratify:

```rego
remote_data := response {
  containers := object.get(input.review.object.spec, "containers", [])
  init_containers := object.get(input.review.object.spec, "initContainers", [])
  ephemeral_containers := object.get(input.review.object.spec, "ephemeralContainers", [])
  all_containers := array.concat(array.concat(containers, init_containers), ephemeral_containers)
  images := [c.image | c = all_containers[_]]
  response := external_data({"provider": "ratify-provider", "keys": images})
}
```

---

## Troubleshooting

Real problems hit standing this up, kept here so the next debugging session (mine or anyone else's) doesn't start from zero. Full detail in `docs/evidence/troubleshooting-notes.md`.

1. **Ratify Helm install fails: "must provide a TLS certificate"**
   Fix: `--set featureFlags.RATIFY_CERT_ROTATION=true` for local/test clusters.

2. **`Verifier` stuck at `CONFIG_INVALID` even after fixing the YAML on disk**
   `kubectl apply` performs a two-way merge -- stale fields from an earlier, broken version of the resource persist even when the file no longer contains them. Fix: `kubectl delete` then `kubectl apply`, not repeated `apply`.

3. **Cosign trust policy field is `scopes`, not `registryScopes`**
   `registryScopes` is the Notation verifier's field name. Using it on a Cosign `Verifier` produces `CONFIG_INVALID: scopes parameter is required`.

4. **Gatekeeper reports 0 violations even when Ratify is correctly rejecting images**
   Ratify surfaces per-image verification failures under `remote_data.responses[].isSuccess`, not `remote_data.errors` (that field is reserved for system-level failures like an unreachable registry). Rego that only checks `errors` will silently pass every image regardless of actual verification outcome.

5. **Correctly signed image still rejected: "none of the expected identities matched"**
   The `Verifier`'s `certificateIdentity` must exactly match the workflow file that actually produced the signature. A typo or a stale reference to a renamed workflow file causes real, correctly-signed images to fail identity matching.

6. **Kyverno webhook times out under `kubectl run`**
   Usually cluster resource pressure, not a policy bug -- check `kubectl get events -n kyverno` for `NodeNotReady` / liveness probe timeouts before assuming the policy itself is broken. On minikube with the `docker` driver, memory/CPU allocation is bounded by Docker Desktop's own resource settings, not just the host machine's.

7. **An unsigned/mixed/tampered test pod is created successfully even though `enforcementAction: deny` is set and `totalViolations` correctly shows it as a violation**
   This is not a Rego bug -- it's the Gatekeeper Helm chart's webhook `failurePolicy` defaulting to `Ignore`. When the admission webhook's call to Ratify doesn't return within `validatingWebhookTimeoutSeconds` (default: 3 seconds), Gatekeeper fails **open**: the request is admitted rather than blocked, since the webhook technically never returned a verdict in time. The background **audit** loop has no such timeout and correctly flags the violation after the fact, which is what produces the confusing symptom of "the pod exists, but the Constraint says it's a violation."
   Fix, both parts matter:
   ```bash
   helm upgrade gatekeeper gatekeeper/gatekeeper \
     --namespace gatekeeper-system \
     --reuse-values \
     --set validatingWebhookTimeoutSeconds=10 \
     --set validatingWebhookFailurePolicy=Fail
   ```
   Note the Helm value key is `validatingWebhookFailurePolicy`, not `failurePolicy` -- the latter is silently ignored by the chart with no error, which makes this easy to think you've fixed when you haven't. Confirm with:
   ```bash
   kubectl get validatingwebhookconfigurations gatekeeper-validating-webhook-configuration \
     -o jsonpath='{.webhooks[0].failurePolicy} {.webhooks[0].timeoutSeconds}'
   ```
   Should print `Fail 10`.

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

## Required GitHub Secrets

| Secret | Description |
|---|---|
| `DOCKERHUB_USERNAME` | Docker Hub username (`5936`) |
| `DOCKERHUB_TOKEN` | Docker Hub access token -- create at hub.docker.com -> Account Settings -> Security |

---

## Dependabot Cooldown

`dependabot.yml` sets `cooldown.default-days: 7` for both the `github-actions` and `pip` ecosystems. This delays Dependabot from opening a PR for a newly published release until it's been out for 7 days. A brand-new GitHub Action or pip package version is, briefly, less trustworthy than one that's had a week of real-world usage -- the cooldown gives the ecosystem time to catch obvious regressions or supply chain issues (a compromised release, a broken build) before this repo pulls it in.

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

## Deploying to EKS

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
kubectl apply -f policy/gatekeeper/
kubectl get k8srequiresignedimages require-signed-images -o yaml
# Promote through warn, then deny, once violations look correct
```

---

## Tool Responsibilities

| Tool | Role |
|---|---|
| [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect) | Provides the identity token used for keyless signing -- no secrets needed |
| [Fulcio](https://docs.sigstore.dev/certificate_authority/overview/) | Sigstore CA -- issues short-lived signing certificates bound to the OIDC identity |
| [Cosign](https://docs.sigstore.dev/cosign/overview/) | Signs image digests, attaches SBOM and provenance attestations as OCI artifacts |
| [Rekor](https://docs.sigstore.dev/logging/overview/) | Public append-only transparency log -- stores signatures and certificates durably |
| [Syft](https://github.com/anchore/syft) | Generates SPDX JSON SBOMs from the container image |
| [Trivy](https://trivy.dev/) | Scans filesystem and container images for CVEs, secrets, and misconfigurations |
| [Semgrep](https://semgrep.dev/docs/) | SAST -- scans source, workflows, Dockerfile, and manifests for security issues |
| [Kyverno](https://kyverno.io/docs/) | Kubernetes admission controller -- verifies signatures/attestations natively (Option A) |
| [Gatekeeper](https://open-policy-agent.github.io/gatekeeper/website/docs/) | Kubernetes admission controller -- delegates verification to Ratify (Option B) |
| [Ratify](https://ratify.dev/docs/quickstarts/quickstart-manifest-validation) | Performs the actual Cosign verification on Gatekeeper's behalf via external data provider |
| [Dependabot](https://docs.github.com/en/code-security/dependabot) | Keeps GitHub Actions SHA pins up to date weekly |

---

## Known Limitations

- The verify workflow runs in the same pipeline as sign. A fully separated architecture would trigger verification in a deployment pipeline, not immediately after signing. This is tracked as future work.
- Neither enforcement engine parses SBOM contents -- both confirm the SBOM was attached by the approved workflow, not that it contains specific packages.
- VEX statements currently inform `.trivyignore` suppressions but are not yet a verified admission-time attestation. Wiring VEX in as a fourth Cosign attestation type is the natural next step.
- Gatekeeper's status output reports `K8sNativeValidation engine is missing` for the `vap.k8s.io` enforcement point on clusters where that feature isn't enabled. This doesn't affect the webhook-based enforcement path used here, but it's a visible error state worth being aware of rather than ignoring.
- **Fail-open is the Gatekeeper Helm chart default, and it is the wrong default for this project's threat model.** Out of the box, `validatingWebhookFailurePolicy` is `Ignore` -- if the admission webhook's call to Ratify doesn't return within the configured timeout (3 seconds by default), the request is admitted, not blocked. That silently defeats the entire point of enforcing signature verification whenever Ratify is slow, cold-starting, or briefly unreachable. This repo runs with `validatingWebhookFailurePolicy: Fail` and a 10-second timeout instead, which means a pod creation request is blocked, not allowed, if the verifier can't be reached in time. The tradeoff is real and worth stating plainly: with `Fail` set, a Ratify outage or Gatekeeper restart can temporarily block *all* pod creation cluster-wide, not just unsigned images, since the webhook cannot render any verdict at all. For a security control whose entire purpose is proving unsigned images can't slip through, fail-closed is the correct choice despite that availability cost -- but it is a genuine cost, and any team adopting this pattern should decide on it deliberately rather than inheriting the chart's default silently.
- The pipeline targets Docker Hub. Migration to Amazon ECR with IRSA-based authentication is the recommended path for AWS production deployments.
- Kyverno and Gatekeeper+Ratify are documented here as parallel options for comparison. Running both simultaneously against the same workloads in production is not recommended -- it adds operational complexity (two webhooks to reason about, two places enforcement can silently diverge) without additional security benefit over choosing one well-configured engine.