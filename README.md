# supply-chain-security

A software supply chain security pipeline built on GitHub Actions, Sigstore, and Kubernetes admission control. Every image that reaches the cluster has been scanned, signed, and attested before Kyverno and Gatekeeper let it anywhere near a node. Runtime behavior is monitored by Falco via eBPF after admission.

Two independent enforcement engines are implemented and documented in this repo: **Kyverno** (verifies signatures/attestations natively) and **Gatekeeper + Ratify** (Gatekeeper delegates verification to Ratify via the `external_data` built-in). Both are tested against the same set of signed, unsigned, tampered, and mixed-container test cases. Runtime detection is layered on top via Falco, deployed alongside both engines.

## What This Project Does

Every push to `main` triggers a pipeline that:

1. Builds a multi-stage Docker image from a pinned Debian Bookworm base
2. Scans the image for critical vulnerabilities with Trivy
3. Signs the image digest with Cosign keyless signing (no private keys stored anywhere)
4. Generates an SPDX SBOM with Syft and attaches it as a Cosign attestation
5. Generates a SLSA provenance predicate and attaches it as a Cosign attestation
6. Verifies all three attestations before the pipeline completes
7. Blocks any unsigned or unattested image from running in Kubernetes, enforced at admission time
8. Watches runtime behavior of running containers via Falco eBPF — shells, unexpected API calls, privilege escalation

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
       |
       v
Runtime (Falco + Falcosidekick)
  -- eBPF syscall monitoring on every node
  -- Shell spawn detection in signed workload pods
  -- Unexpected Kubernetes API server contact (allowlisted known callers)
  -- Alerts: Falco → Falcosidekick → Pub/Sub → Cloud Function → Discord
```

No private keys are stored anywhere in the CI pipeline. The signing identity is derived from the GitHub Actions OIDC token and pinned to the Sigstore public transparency log (Rekor). Certificate lifetime is ~10 minutes; verification uses the Rekor log, not the certificate.

**What this proves, and what it doesn't.** Everything above establishes that an image was built, signed, and attested by an unmodified run of this repo's CI against a specific commit on `main` — and that nothing unsigned or unattested can be scheduled. Falco extends this to runtime: it watches what signed, admitted containers actually do once they're running. Neither layer substitutes for the other.

---

## Repository Structure

```
.
├── app/
│   ├── main.py                  # FastAPI application (3 endpoints)
│   └── requirements.txt         # Pinned Python dependencies
├── Dockerfile                   # Multi-stage, non-root, Bookworm-pinned
├── .trivyignore                 # Documented CVE suppressions with justification
├── renovate.json                # Dependency updates: GitHub Actions, pip, Docker, Terraform
├── .github/
│   ├── CODEOWNERS               # Required reviewers for trust-chain-affecting paths
│   ├── dependabot.yml           # Disabled — superseded by Renovate
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
│   │   ├── pod-hardening-template.yaml    # OPA Rego: seccomp, readOnlyRootFilesystem, capabilities
│   │   ├── pod-hardening-constraint.yaml  # K8sRequirePodHardening, namespace scope
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

Images are stored in Google Artifact Registry (GAR), not Docker Hub. Authentication from GitHub Actions to GCP uses Workload Identity Federation — no service account JSON keys are stored as GitHub secrets.

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

The WIF pool (`github-pool`) and provider (`github-provider`) are scoped to this repo via an `attribute.repository` condition — tokens from other repos in the same org cannot exchange for credentials here.

The reusable composite action at `.github/actions/gcp-auth/action.yml` wraps `google-github-actions/auth` and `gcloud auth configure-docker`. All workflows that need GAR access call this action rather than duplicating the auth logic.

**Required repository variables** (not secrets — these aren't sensitive):
- `GCP_WORKLOAD_IDENTITY_PROVIDER` — the full WIF provider resource name
- `GCP_SA_EMAIL` — `supply-chain-ci@<project>.iam.gserviceaccount.com`

### PR gate (pr-check.yml)

Runs on every pull request targeting `main`. No build, no push. Fast feedback on code quality and vulnerabilities before anything is merged.

- Semgrep scans source code, GitHub Actions workflows, Dockerfile, and Kubernetes manifests using `--config auto`
- Trivy scans the filesystem for dependency CVEs, secrets, and misconfigurations
- Both upload SARIF to the GitHub Security tab
- Either finding blocks the merge

### Deploy pipeline (deploy.yml)

Runs on push to `main` only. Trusts that the PR gate already passed.

Three reusable workflows called in sequence: `build-push` → `sign-attest` → `verify`. Each job depends on the previous via `needs:`. The image digest flows from `build-push` outputs through to `verify` without re-tagging.

### Why this separation matters

Signing happens only on `main`. No signed images are produced from feature branches. Both enforcement engines' identity checks (`sign-attest.yml@refs/heads/main`) are meaningful because they map to a single, protected branch that can't be pushed to directly.

### Trigger scoping

Both `deploy.yml` and `pr-check.yml` are path-filtered:

- `deploy.yml` triggers only on changes to `app/**`, `Dockerfile`, or `.dockerignore` — a README edit or a policy YAML tweak alone does not rebuild, re-sign, or re-push an image.
- `pr-check.yml` triggers on the same application paths, plus `.github/workflows/**` and `.github/actions/**` — changes to CI itself are scanned before merge.

### SBOM + VEX generation (non-blocking)

`sbom-vex.yml` runs in parallel with `sign-attest` rather than gating it. SBOM/VEX generation is valuable but shouldn't block a deploy if it's slow or transiently unavailable.

---

## Runtime Detection (Falco)

Admission control answers one question: is this image allowed to run? Falco answers the next one: what is it doing once it's running?

Falco uses eBPF to observe syscalls at the kernel level in real time, matching them against rules. It doesn't care whether an image was signed — by the time Falco sees anything, that question's already been answered by Kyverno or Gatekeeper. Falco's job starts where admission control's job ends.

### Custom rule: shell spawn detection

Every image in this cluster is built through a pipeline with no interactive tooling included by design. A shell appearing in a running pod isn't ambiguous — it's either someone debugging in a way they shouldn't, or something worse.

```yaml
- rule: Shell Spawned In Signed Workload Pod
  desc: >
    No pod in this cluster should ever exec a shell - every image is
    built, signed, and admitted through the supply-chain-security
    pipeline with no interactive tooling included by design.
  condition: >
    spawned_process and container and
    proc.name in (shell_binaries) and
    not k8s.ns.name in (kube-system, falco-system)
  output: >
    Unexpected shell spawned in hardened pod
    (user=%user.name pod=%k8s.pod.name ns=%k8s.ns.name
    container=%container.name image=%container.image.repository
    cmdline=%proc.cmdline)
  priority: CRITICAL
```

### Alert path

```
Falco → Falcosidekick → Pub/Sub → Cloud Function → Discord
```

The chain from Pub/Sub onward runs independent of whether Falco itself is still running, which matters for a cluster that isn't kept alive around the clock.

### Noise reduction

Falco's default ruleset fires `Contact K8S API Server From Container` on every `external-dns` Ingress check and every Gatekeeper audit loop reconciliation. Both are expected behavior, not threats. The default ruleset ships an empty override macro for exactly this case:

```yaml
- macro: user_known_contact_k8s_api_server_activities
  condition: >
    (k8s.ns.name = "external-dns" and proc.name = "external-dns") or
    (k8s.ns.name = "gatekeeper-system" and proc.name = "manager")
```

Falco loads its default rules first, then any custom rules file. The later macro definition wins, replacing the default's `(never_true)` condition with an explicit allowlist scoped to both namespace and process name — not namespace alone. Allowlisting the whole `gatekeeper-system` namespace would silence a genuinely suspicious process if one ever appeared there.

### Rule matching gotcha

Since Falco v0.36.0, the default `rule_matching` behavior is `first` — it stops evaluating rules the moment any one rule matches an event. If a built-in rule matches before a custom rule, the custom rule never fires, with no warning anywhere that this is happening.

```hcl
falco = {
  rule_matching = "all"
}
```

Set permanently in Terraform. Without it, the custom shell-spawn rule loaded, showed as `enabled: true`, and silently never fired because the bundled `Terminal shell in container` rule won the race every time.

### Deployment

Both the Falco module and the alerting path (Falcosidekick + Pub/Sub + Cloud Function) are Terraform, in `gcp-infrastructure-modules`. No manual `kubectl` steps required to stand it up from zero.

**Helm timeout on fresh clusters:** GKE nodes can look schedulable and still flip briefly to `NotReady` while kubelet and the CNI finish settling. On a cold cluster rebuild, daemonset pods land on these nodes and get rescheduled, eating past Helm's default 300-second timeout before the daemonset stabilizes. Set `timeout = 600` on the `helm_release` resource. If a previous failed apply left a release record behind, clear it before retrying:

```bash
helm uninstall falco -n falco-system --no-hooks
kubectl delete secret -n falco-system -l owner=helm,name=falco
```

---

## Vulnerability Management

Trivy runs twice per deploy:

- **Pre-build (security-scan.yml):** filesystem scan on the source repo — catches dependency CVEs before the image is built
- **Post-push (build-push.yml):** image scan on the pushed digest — catches base image CVEs that only appear after the image is assembled

Critical CVEs with no available fix are suppressed in `.trivyignore` with documented justification for each entry. Each suppression explains why the vulnerable code path is unreachable or inapplicable to this deployment.

### VEX (planned enforcement layer, currently triage-only)

VEX statements classify each finding:

- **Not Affected** — the vulnerable function is not called in this codebase
- **Affected** — impacted, mitigation in place
- **Fixed** — resolved in the current version
- **Under Investigation** — triage in progress

VEX is currently used as documentation to justify `.trivyignore` suppressions, not yet wired into admission enforcement. The natural next step is attaching VEX documents as a fourth Cosign attestation type and verifying them at admission time.

---

## Pod Hardening (Gatekeeper)

Runtime detection catches bad behavior. Pod hardening prevents some of it from being possible in the first place.

A `require-pod-hardening` ConstraintTemplate enforces three settings on every pod:

- `seccompProfile.type: RuntimeDefault` — filters syscalls at the kernel level before Falco even sees them
- `readOnlyRootFilesystem: true` — prevents writing to the container filesystem at runtime
- `capabilities.drop: [ALL]` — removes every Linux capability the container doesn't need

Both the signing policy and the hardening policy follow the same three-stage rollout: `dryrun` → `warn` → `deny`.

**Two Rego bugs found during implementation:**

1. Using the `in` keyword without `import future.keywords.in` fails the whole template at ingest time. Gatekeeper logs it clearly.
2. Checking `container.securityContext.capabilities.drop` against a pod with an entirely empty `securityContext` doesn't evaluate to `false` — it evaluates to `undefined`, and in Rego, a rule built on an undefined value simply doesn't fire. No violation, no error. Fixed by restructuring so `not <undefined>` resolves to `true`.

---

## Enforcement, Option A: Kyverno

The `block-unsigned-images` ClusterPolicy runs in `Enforce` mode and applies to all namespaces except `kube-system`, `kyverno`, `argocd`, `crossplane-system`, and `cert-manager`.

Three rules must all pass before a Pod is admitted:

**Rule 1 — verify-image-signature**
Verifies a valid Cosign keyless signature exists in Rekor for the image digest. Checks certificate subject and OIDC issuer. `verifyDigest: true` prevents tag substitution attacks.

**Rule 2 — verify-sbom-attestation**
Verifies a Cosign attestation of type `spdxjson` exists and was signed by the same identity. `verifyDigest: true` enforced.

**Rule 3 — verify-provenance-attestation**
Verifies a Cosign attestation of type `slsaprovenance` exists and validates three conditions:

- `invocation.configSource.entryPoint` matches `.github/workflows/sign-attest.yml`
- `builder.id` matches `https://github.com/actions/runner`
- `invocation.configSource.uri` matches `git+https://github.com/musaumakau/supply-chain-security@refs/heads/main`

The third condition is the critical one — it prevents provenance generated from a fork or a different repository from being accepted.

**`maxContextSize`:** Kyverno's default context size limit (2Mi) is too small for a combined signature + SBOM + provenance attestation payload (real-world size: ~5.7MB combined). Set it to 8Mi:

```bash
helm upgrade kyverno kyverno/kyverno \
  --namespace kyverno \
  --reuse-values \
  --set config.maxContextSize=8Mi
```

Do not patch the ConfigMap directly — it gets silently reverted on the next `helm upgrade`.

---

## Enforcement, Option B: Gatekeeper + Ratify

Gatekeeper does not verify signatures itself. It calls out to **Ratify** via the `external_data` Rego built-in at admission time; Ratify performs the actual registry lookup and Cosign verification and returns a pass/fail result.

### Chain of resources, in dependency order

1. **`Store`** (`store-oras.yaml`) — tells Ratify how to fetch signature/attestation artifacts from the registry
2. **`Verifier`** (`verifier-cosign.yaml`) — defines the trust policy: registry scopes, expected keyless certificate identity + OIDC issuer
3. **`ConstraintTemplate`** (`constraint-template.yaml`) — the Rego that calls Ratify's external data provider and turns a failed verification into a Gatekeeper violation
4. **`Constraint`** (`constraint.yaml`) — binds the template to a scope and sets the enforcement stage

### GAR authentication for Ratify

Ratify needs read access to GAR to pull Cosign signatures and attestations. Unlike the CI pipeline (WIF) and Kyverno (GKE Workload Identity), Ratify has no native GCP Workload Identity auth provider. The only reliable option is a **long-lived GCP service account JSON key**, scoped minimally to `roles/artifactregistry.reader`. This is a deliberate architectural tradeoff documented in `docs/decisions/ratify-gcp-auth-tradeoff.md`. **Rotate every 90 days.**

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

### Disable the Gatekeeper mutating webhook

```bash
kubectl delete mutatingwebhookconfiguration gatekeeper-mutating-webhook-configuration
```

### Applying the CRDs

Order matters:

```bash
kubectl apply -f policy/gatekeeper/store-oras.yaml
kubectl apply -f policy/gatekeeper/verifier-cosign.yaml

kubectl apply -f policy/gatekeeper/constraint-template.yaml
kubectl wait --for=condition=established \
  crd/k8srequiresignedimages.constraints.gatekeeper.sh --timeout=30s
kubectl apply -f policy/gatekeeper/constraint.yaml
```

### Webhook failure policy

Set before testing enforcement:

```bash
helm upgrade gatekeeper gatekeeper/gatekeeper \
  --namespace gatekeeper-system \
  --reuse-values \
  --set validatingWebhookTimeoutSeconds=10 \
  --set validatingWebhookFailurePolicy=Fail
```

Confirm: `kubectl get validatingwebhookconfigurations gatekeeper-validating-webhook-configuration -o jsonpath='{.webhooks[0].failurePolicy} {.webhooks[0].timeoutSeconds}'` should print `Fail 10`.

---

## Test Evidence

Every claim above is backed by a real command run against a live GKE cluster (`prod-cluster`, `europe-west1`), not just policy YAML assumed to work. Raw output lives in `docs/evidence/`.

### Gatekeeper + Ratify

| Test case | Expected result | Verified |
|---|---|---|
| Signed image via ArgoCD (digest-pinned) | Admitted, `Synced`/`Healthy` | Yes |
| Unsigned image via `kubectl run` | Blocked at admission | Yes — `[require-signed-images] image '...' failed Cosign signature verification` |
| Signed image still admitted after flipping to `deny` mode | Admitted | Yes |
| Pod with signed main container + unsigned `initContainer` | Blocked | Yes |

### Kyverno

| Test case | Expected result | Verified |
|---|---|---|
| Signed image via ArgoCD (digest-pinned) | Admitted, `Synced`/`Healthy` | Yes — `docs/evidence/kyverno-signed-admitted.txt` |
| Unsigned image via `kubectl apply` | Blocked | Yes — `docs/evidence/kyverno-unsigned-rejected-gke.txt` |
| Unsigned image via ArgoCD (negative-test Application) | `SyncFailed` | Yes |
| Tampered signature | Blocked | Yes — `docs/evidence/kyverno-tampered-rejected.txt` |
| Pod with signed main container + unsigned `initContainer` | Blocked | Yes — `docs/evidence/kyverno-mixed-containers-rejected-gke.txt` |

### Falco

| Test case | Expected result | Verified |
|---|---|---|
| `kubectl exec` into a signed running pod | CRITICAL alert in Discord within 1 second | Yes |
| `external-dns` checking Ingress objects | No alert (allowlisted) | Yes |
| Gatekeeper audit loop reconciliation | No alert (allowlisted) | Yes |

---

## Kyverno Bugs Found During Live Testing

**1. Provenance rule used the wrong JMESPath scope and the wrong expected value.** The condition read `{{ predicate.invocation.configSource.entryPoint }}` and expected `.github/workflows/deploy.yml`. Both wrong: Kyverno scopes JMESPath directly to the predicate body (no `predicate.` prefix), and the workflow that actually signs is `sign-attest.yml`, not `deploy.yml`.

**2. `sign-attest.yml` hardcoded its own entrypoint as a string literal.** Fixed by deriving it at runtime from the OIDC token's `job_workflow_ref` claim.

**3. Every rule's `imageReferences` listed both `index.docker.io/5936/*` and `docker.io/5936/*`.** These aren't two registries — `docker.io` always resolves to `index.docker.io`.

**4. Kyverno's `maxContextSize` (default 2Mi) was too small for a real SBOM.** Real combined attestation size: ~5.7MB. Set to 8Mi via Helm.

None of these were caught by code review alone — only found by running test cases against a live cluster.

---

## Troubleshooting

Real problems encountered standing this up. Full detail in `docs/runbooks/troubleshooting-gatekeeper-kyverno.md`.

1. **Ratify Helm install fails: "must provide a TLS certificate"** — Fix: `--set featureFlags.RATIFY_CERT_ROTATION=true`

2. **`Verifier` stuck at `CONFIG_INVALID: 'key' and 'rekorURL' are part of Cosign legacy configuration`** — The Helm chart injects a stale `key:` field. Remove it: `kubectl patch verifier verifier-cosign --type=json -p='[{"op": "remove", "path": "/spec/parameters/key"}]'`

3. **Gatekeeper mutating webhook blocks every admission with 403** — Delete it: `kubectl delete mutatingwebhookconfiguration gatekeeper-mutating-webhook-configuration`

4. **Ratify auth fails (403) after creating `ratify-gar-regcred`** — The Secret was probably created before the `gatekeeper-system` namespace existed and got deleted silently. Re-run `create-ratify-secret.sh`.

5. **Correctly signed image rejected in audit loop but not at admission** — Ratify's credential cache TTL is hardcoded at 12 hours. A Secret update alone doesn't flush it: `kubectl rollout restart deployment/ratify -n gatekeeper-system`

6. **`Constraint` stuck at `CONFIG_INVALID` even after fixing YAML on disk** — `kubectl apply` performs a two-way merge; stale fields from an earlier broken version persist. Fix: `kubectl delete` then `kubectl apply`.

7. **Cosign trust policy field is `scopes`, not `registryScopes`** — `registryScopes` is the Notation verifier's field name.

8. **Gatekeeper reports 0 violations even when Ratify is correctly rejecting images** — Ratify surfaces per-image failures under `remote_data.responses[].isSuccess`, not `remote_data.errors`.

9. **"none of the expected identities matched"** — The `Verifier`'s `certificateIdentity` must exactly match the workflow file that produced the signature, including path.

10. **Unsigned test pod created successfully despite `enforcementAction: deny`** — `validatingWebhookFailurePolicy` defaults to `Ignore`. Set it to `Fail` via Helm.

11. **Kyverno webhook times out under `kubectl run`** — Usually cluster resource pressure. Check `kubectl get events -n kyverno` for `NodeNotReady` before assuming the policy is broken.

12. **Falco custom rule loads, shows `enabled: true`, but never fires** — `rule_matching` defaults to `first` since v0.36.0. Set `rule_matching = "all"` in Terraform.

13. **Falco `helm_release` times out on fresh cluster rebuild** — GKE nodes flip briefly to `NotReady` during CNI init. Set `timeout = 600` on the `helm_release`. If a previous failed apply left a release behind, clear it first: `helm uninstall falco -n falco-system --no-hooks && kubectl delete secret -n falco-system -l owner=helm,name=falco`

14. **`constraint-template.yaml` rejected with `unknown field "spec.crd.names"`** — `names:` must be nested under `spec:`, not a sibling of it.

---

## Application Endpoints

| Endpoint | Response |
|---|---|
| `GET /` | `{"status": "ok", "service": "supply-chain-demo"}` |
| `GET /health` | `{"status": "healthy", "service": "supply-chain-demo"}` |
| `GET /info` | Git SHA, signed flag, service name |

Any running pod that reaches `/info` has already passed through admission control — it proves the image was signed and attested before reaching the cluster.

---

## Dependency Updates (Renovate)

Dependabot is disabled in favour of [Renovate](https://docs.renovatebot.com/), which covers all four ecosystems in one tool: GitHub Actions, pip, Docker base images, and Terraform providers.

Key config decisions:
- `minimumReleaseAge: 7 days` — no PR is opened for a package published less than 7 days ago
- Python Docker base image major/minor bumps are disabled — only patch updates (`3.12.x → 3.12.y`) are proposed
- GitHub Actions SHA digests are pinned automatically (`pinDigests: true`)
- Schedule: Mondays 09:00–17:00 EAT

---

## Required Configuration

### GitHub repository variables (not secrets)

| Variable | Value |
|---|---|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `projects/<number>/locations/global/workloadIdentityPools/github-pool/providers/github-provider` |
| `GCP_SA_EMAIL` | `supply-chain-ci@<project>.iam.gserviceaccount.com` |

### GCP infrastructure

Managed in `gcp-infrastructure-modules` via Terraform:

- Workload Identity Federation pool + provider scoped to `musaumakau/supply-chain-security`
- `supply-chain-ci` GSA with `roles/artifactregistry.writer` (repo-scoped)
- `kyverno-gar-reader` GSA with `roles/artifactregistry.reader` bound to Kyverno KSAs via Workload Identity
- `ratify-gar-reader` GSA with `roles/artifactregistry.reader`, long-lived JSON key stored as `ratify-gar-regcred` in `gatekeeper-system`
- Falco + Falcosidekick (Helm), Pub/Sub topic, Cloud Function (Discord alerting)

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

## Tool Responsibilities

| Tool | Role |
|---|---|
| [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect) | Provides the identity token used for keyless signing |
| [GCP Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation) | Allows GitHub Actions to authenticate to GCP without storing service account keys |
| [Google Artifact Registry](https://cloud.google.com/artifact-registry) | Container registry for signed images and attestations |
| [Fulcio](https://docs.sigstore.dev/certificate_authority/overview/) | Sigstore CA — issues short-lived signing certificates bound to the OIDC identity |
| [Cosign](https://docs.sigstore.dev/cosign/overview/) | Signs image digests, attaches SBOM and provenance attestations as OCI artifacts |
| [Rekor](https://docs.sigstore.dev/logging/overview/) | Public append-only transparency log — stores signatures and certificates durably |
| [Syft](https://github.com/anchore/syft) | Generates SPDX JSON SBOMs from the container image |
| [Trivy](https://trivy.dev/) | Scans filesystem and container images for CVEs, secrets, and misconfigurations |
| [Semgrep](https://semgrep.dev/docs/) | SAST — scans source, workflows, Dockerfile, and manifests for security issues |
| [Kyverno](https://kyverno.io/docs/) | Kubernetes admission controller — verifies signatures/attestations natively (Option A) |
| [Gatekeeper](https://open-policy-agent.github.io/gatekeeper/website/docs/) | Kubernetes admission controller — delegates verification to Ratify (Option B) |
| [Ratify](https://ratify.dev/docs/quickstarts/quickstart-manifest-validation) | Performs the actual Cosign verification on Gatekeeper's behalf via external data provider |
| [Falco](https://falco.org/docs/) | eBPF runtime security — detects unexpected behavior in running containers |
| [Falcosidekick](https://github.com/falcosecurity/falcosidekick) | Routes Falco alerts to external destinations (Pub/Sub, Discord) |
| [ArgoCD](https://argo-cd.readthedocs.io/) | GitOps deployment — happy-path and negative-test Applications |
| [Renovate](https://docs.renovatebot.com/) | Keeps GitHub Actions, pip, Docker base images, and Terraform providers up to date |

---

## Known Limitations

- The verify workflow runs in the same pipeline as sign. A fully separated architecture would trigger verification in a deployment pipeline, not immediately after signing.
- Neither enforcement engine parses SBOM contents — both confirm the SBOM was attached by the approved workflow, not that it contains specific packages.
- VEX statements currently inform `.trivyignore` suppressions but are not yet a verified admission-time attestation.
- **Ratify has no native GCP Workload Identity auth provider.** AWS IRSA, Azure Managed Identity, and Alibaba RRSA are all supported; GCP is not (as of Ratify v1.15.x). A long-lived JSON key is the current workaround.
- **Fail-open is the Gatekeeper Helm chart default.** `validatingWebhookFailurePolicy` defaults to `Ignore`. This repo runs with `Fail`.
- **Namespace exclusions are a full bypass.** Both Kyverno and Gatekeeper exclude system namespaces. Any workload running in an excluded namespace bypasses enforcement entirely.
- Kyverno and Gatekeeper+Ratify are documented here as parallel options for comparison. Running both simultaneously against the same workloads in production is not recommended.

---

Both the Falco module and the GCP infrastructure this builds on are in `gcp-infrastructure-modules`. The admission-control pipeline is in this repo (`supply-chain-security`).