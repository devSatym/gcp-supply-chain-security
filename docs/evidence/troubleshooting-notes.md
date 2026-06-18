# Troubleshooting Notes -- Gatekeeper + Ratify + Kyverno + CI/CD

Format per entry: **Symptom** (what you actually see) -> **Cause** -> **Fix** -> **Verify** (how to confirm it's actually fixed, not just applied).

---

## Gatekeeper + Ratify

### 1. Ratify Helm install fails with "must provide a TLS certificate"

**Symptom:** `helm install ratify ...` fails outright, error mentions a missing TLS certificate.

**Cause:** Ratify's webhook requires cert rotation to be explicitly enabled; it's not on by default in the chart.

**Fix:**
```bash
helm install ratify ratify/ratify --set featureFlags.RATIFY_CERT_ROTATION=true
```

**Verify:** `kubectl get pods -n gatekeeper-system` shows the Ratify pod reaching `1/1 Running` without a cert-related crash loop.

---

### 2. Ratify Verifier stuck `CONFIG_INVALID` after fixing the YAML

**Symptom:** You corrected the Verifier CRD's YAML, re-applied it, and it's still reporting `CONFIG_INVALID`.

**Cause:** `kubectl apply` performs a merge, not a replace. Stale fields from an earlier, broken version of the resource can persist alongside your fix.

**Fix:** Delete before re-applying, don't apply-over-apply:
```bash
kubectl delete -f policy/gatekeeper/verifier-cosign.yaml
kubectl apply -f policy/gatekeeper/verifier-cosign.yaml
```

**Verify:** `kubectl get verifiers.config.ratify.deislabs.io -o yaml` shows the corrected config with no leftover fields from the prior version.

---

### 3. Cosign trust policy field is `scopes`, not `registryScopes`

**Symptom:** Ratify Verifier config silently doesn't scope to the expected registry.

**Cause:** `registryScopes` is the Notation verifier's field name, not Cosign's. Easy to cross-reference from Notation examples and get wrong.

**Fix:** Use `scopes` in the Cosign verifier block specifically.

**Verify:** Check the applied CRD's spec matches the field name Ratify's own Cosign verifier schema expects (not Notation's).

---

### 4. Gatekeeper Rego checked `remote_data.errors` only

**Symptom:** `totalViolations` stayed at `0` even when Ratify was actively rejecting an image.

**Cause:** Ratify surfaces per-image verification failures under `remote_data.responses[].isSuccess: false`, not under `remote_data.errors`. The Rego only checked the latter.

**Fix:** Check `remote_data.responses[].isSuccess` explicitly in the constraint template's Rego.

**Verify:** `docs/evidence/unsigned-rejected.txt` -- a genuinely unsigned image produces a real denial, not a silent pass.

---

### 5. Rego only evaluated `spec.containers`

**Symptom:** An unsigned image placed in `initContainers` was admitted cleanly -- a real bypass, since init containers run with full volume access before the verified main container starts.

**Cause:** The image list sent to Ratify was built from `spec.containers` only.

**Fix:** Concatenate `containers`, `initContainers`, and `ephemeralContainers` before building the image list (see `init-container-gap-fix.md` for the full before/after).

**Verify:** `docs/evidence/init-container-rejected.txt`.

---

## Kyverno

### 6. Provenance rule rejects every image, signed or not

**Symptom:** `verify-provenance-attestation` fails unconditionally, including for images that are correctly signed and attested.

**Cause:** Two independent bugs stacked: the condition used `{{ predicate.invocation.configSource.entryPoint }}`, but Kyverno scopes JMESPath directly to the predicate body inside an attestation condition -- there is no top-level `predicate` key, so this fails before it even compares values. Separately, the expected value was `.github/workflows/deploy.yml`, the orchestrator workflow, not `sign-attest.yml`, the workflow that actually produces the provenance.

**Fix:** Drop the `predicate.` prefix on all three condition keys in Rule 3; correct the expected `entryPoint` value to `.github/workflows/sign-attest.yml`.

**Verify:** `docs/evidence/kyverno-signed-admitted.txt` -- a correctly signed image is admitted with all three rules passing, not just Rule 1.

---

### 7. `sign-attest.yml`'s embedded entrypoint goes stale after a workflow rename

**Symptom:** Provenance predicate's `entryPoint` field doesn't match the workflow that's currently signing images, even though the YAML "looks right."

**Cause:** The entrypoint was a hardcoded string literal. It was correct when written, but had no mechanism to stay correct after the workflow file was renamed (from an earlier `image-sign-verify.yml`).

**Fix:** Derive it at runtime from the OIDC token's `job_workflow_ref` claim instead of a literal. Note: `github.workflow_ref` (the context variable) resolves to the *calling* workflow, not the reusable one doing the actual signing, and there is no `github.job_workflow_ref` context property -- `job_workflow_ref` only exists inside the OIDC JWT itself, so getting it requires requesting and decoding that token directly (see the `Generate and attest provenance` step).

**Verify:**
```bash
cosign download attestation --predicate-type=https://slsa.dev/provenance/v0.2 \
  docker.io/5936/supply-chain-demo@sha256:<digest> \
  | jq -r '.payload' | base64 -d | jq '.predicate.invocation.configSource.entryPoint'
```
Should print the current, real workflow filename.

---

### 8. `imageReferences` listing both `index.docker.io/...` and `docker.io/...` doubles context cost

**Symptom:** `context size limit exceeded: N bytes` where N is roughly double the actual measured attestation size.

**Cause:** `docker.io` always resolves to `index.docker.io` -- they're not two registries, they're one registry under two spellings. A single image matched both patterns, so each attestation got fetched and loaded into Kyverno's evaluation context twice per admission request.

**Fix:** Keep exactly one pattern per rule (`docker.io/5936/*`), not both.

**Verify:** Measure the real attestation size and confirm the error, if it recurs, now roughly matches that number rather than double it:
```bash
cosign download attestation --predicate-type=https://spdx.dev/Document \
  docker.io/5936/supply-chain-demo@sha256:<digest> \
  | jq -r '.payload' | base64 -d | wc -c
```

---

### 9. `maxContextSize` (default 2Mi) too small for a real SBOM

**Symptom:** `context size limit exceeded` even after fixing the duplicate-pattern bug above.

**Cause:** A real SBOM with a full dependency tree can genuinely exceed Kyverno's 2Mi default context budget.

**Fix:** Raise it via the Helm value, not a raw `kubectl patch` on the ConfigMap (which gets silently reverted on the next unrelated `helm upgrade` if Kyverno is Helm-managed):
```bash
helm upgrade kyverno kyverno/kyverno -n kyverno --reuse-values \
  --set config.maxContextSize=5Mi
```
Size it comfortably above the real measured SBOM size (see #8's verify command), not an arbitrary large number -- this is a real memory safety valve, not just an obstacle.

**Verify:** Re-run the init-container test manifest; `verify-sbom-attestation` and `verify-provenance-attestation` should evaluate with a real pass/fail verdict, no size error.

---

### 10. Kyverno Helm upgrade fails on `kyverno-hook-post-upgrade`

**Symptom:** `helm upgrade` fails with `post-upgrade hooks failed: timed out waiting for the condition`, even though the actual config change (e.g. `maxContextSize`) already applied successfully.

**Cause:** A known Kyverno chart issue (kyverno/kyverno#9780) -- the post-upgrade PolicyReport-cleanup hook Job can get stuck `NotReady` even after finishing its actual work.

**Fix:** Disable the hook for the upgrade:
```bash
helm upgrade kyverno kyverno/kyverno -n kyverno --reuse-values \
  --set policyReportsCleanup.enabled=false
```

**Verify:** `helm status kyverno -n kyverno` shows `STATUS: deployed` on a fresh revision, not `failed`.

---

### 11. Two fail-closed admission webhooks can deadlock each other

**Symptom:** A routine `kubectl` operation (e.g. restarting a deployment in one namespace) gets rejected by an admission webhook belonging to a completely unrelated namespace/tool.

**Cause:** Kubernetes routes *every* mutating/validating webhook check through *every* registered webhook cluster-wide, regardless of which namespace the request targets, unless explicitly excluded. If Kyverno's admission controller is briefly unreachable, it can block a request to fix Gatekeeper, and vice versa -- a real, live-hit instance of the exact fail-open/fail-closed tradeoff already documented in the README's Known Limitations.

**Fix:** Wait for the unreachable side to recover (usually seconds), or as a last resort, temporarily delete the stuck webhook configuration, perform the fix, and let it re-register itself once healthy.

**Verify:** `kubectl get validatingwebhookconfigurations,mutatingwebhookconfigurations | grep <name>` shows it back and healthy after the underlying pod recovers.

---

## CI/CD and Branch Protection

### 12. Ruleset silently ignores newly-added required checks

**Symptom:** All required checks show green individually (`gh pr checks`, the Checks API), but the PR page still shows a stuck, unsatisfiable check (e.g. `Completed in 3s -- N configurations not found`), and the merge button never becomes clickable.

**Cause:** GitHub's Rulesets API matches required checks by exact string identity against what the Checks API reports for a running job. The full job path shown on the PR page (`PR Check / Policy Unit Tests (pull_request)`) is a different string than the canonical short context GitHub actually stores and matches against (`Policy Unit Tests`). Any workflow restructuring that changes job nesting can silently desync these two, and the underlying check keeps passing fine the whole time -- the mismatch is purely in the Ruleset's bookkeeping.

**Fix:** Use the canonical short `context` name, and pin `integration_id` to the GitHub Actions app specifically, so a context-string collision from some other integration can't accidentally satisfy the rule:
```hcl
required_check {
  context        = "Policy Unit Tests"
  integration_id = 15368
}
```
If a Ruleset is already stuck this way, removing the required checks, saving, then re-adding them through the GitHub UI forces GitHub to recreate the mapping correctly -- update Terraform to match what the UI produces afterward.

**Verify:**
```bash
terraform plan   # should show "No changes" once .tf matches live state
gh pr view --json mergeStateStatus,mergeable   # should show CLEAN / MERGEABLE
```

---

### 13. Confirming required status checks actually block a direct push, not just a PR merge

**Symptom:** Uncertainty about whether `required_status_checks` alone (without an explicit `pull_request` rule type) stops someone from pushing straight to `main`, bypassing review and CI entirely.

**Cause:** Not a bug -- a real question worth testing rather than assuming either way from documentation alone.

**Fix:** N/A -- this confirmed existing protection already works as intended; no config change was needed.

**Verify:** Push a trivial, throwaway commit directly to the protected branch:
```bash
git commit -m "test: confirm ruleset blocks direct push"
git push
```
Expected, confirmed result: `GH013: Repository rule violations... N of N required status checks are expected`, and the push is rejected. Clean up locally with `git reset --hard origin/main` afterward -- the rejected commit never reaches the remote, so there's nothing to revert there.