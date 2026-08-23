# Completion Guide

This guide closes the remaining gaps in the GCP Software Supply Chain & Runtime
Security project. It is written for the current canonical monorepo, not the
obsolete pre-rewrite history described in the original plan.md.

A phase is complete only after the command, GitHub run, Kubernetes result, or
screenshot proving it has been captured. Do not claim an alert, PR gate, or
screenshot that was not actually observed.

## Current baseline

The following work is already complete and must not be repeated:

- The current two-parent merge history is valid.
- The canonical remote is https://github.com/devSatym/gcp-supply-chain-security.git.
- Terraform has provisioned the target GCP project, VPC, GKE, GAR, WIF, IAM,
  Kyverno verifier access, and Falco.
- GitHub deploy run 32630716371 produced and verified the signed image, SPDX
  SBOM, SLSA provenance, and Rekor evidence.
- Argo CD deploys the Helm chart and reports Synced/Healthy.
- Kyverno admits the trusted digest and denies unsigned, wrong-identity,
  wrong-provenance, and unsigned-init-container fixtures.
- Falco detects the controlled shell event in the admitted workload.
- The final Terraform plan previously reported No changes.

The remaining work is closeout and optional external integration:

1. Capture a real PR Semgrep/Trivy run.
2. Capture personal screenshots and command transcripts.
3. Decide whether to enable Discord alerting and, if so, validate every hop.
4. Reconcile the exact planned document names/title and stale evidence fields.
5. Optionally activate the GitHub ruleset after the PR check names are proven.
6. Preserve evidence, then perform an explicit cleanup decision.

## Safety rules

Before every step:

- Do not run git filter-repo, git filter-branch, git replace, git rebase over
  existing history, git cherry-pick of upstream history, git reset to rewrite
  history, or a force push.
- Do not compare the current repository with the obsolete IDs
  cf131149…, d15ce752…, 76c26bd…, or 3d29f6f….
- Do not edit, stage, or commit the user-owned untracked plan.md unless the user
  explicitly requests that separate change.
- Never commit Terraform state, terraform.tfvars, service-account JSON,
  kubeconfig, GitHub tokens, Cosign private material, webhook URLs, or copied
  cloud credentials.
- Do not run terraform destroy without explicit, separately reviewed approval.
- Do not invent a Discord webhook, GCP project, image digest, or GitHub run ID.
- Keep the primary GAR repository immutable and keep Cosign metadata in the
  separate metadata repository already configured by the project.

## 0. Start a fresh-session record

Run from the repository root. These variables contain no secrets:

~~~bash
export REPO_ROOT="$(pwd)"
export GCP_PROJECT="valiant-house-502004-k2"
export GCP_REGION="europe-west1"
export GKE_CLUSTER="prod-cluster"
export GAR_REPOSITORY="europe-west1-docker.pkg.dev/$GCP_PROJECT/supply-chain-security/supply-chain-demo"

test -f "$REPO_ROOT/README.md"
test -f "$REPO_ROOT/docs/repository-merge.md"
git status --short
git branch --show-current
git remote -v
~~~

Expected repository state before doing new work:

~~~text
main
origin https://github.com/devSatym/gcp-supply-chain-security.git
?? plan.md
~~~

If any tracked file is modified unexpectedly, stop and inspect it. Do not use
git clean to remove it.

Obtain cluster credentials only when needed:

~~~bash
gcloud container clusters get-credentials "$GKE_CLUSTER" \
  --region "$GCP_REGION" \
  --project "$GCP_PROJECT"
~~~

## 1. Re-run the canonical history gate

The current history gate uses these exact objects:

~~~bash
export APP_PARENT="cc1fa07a617320a8efdf31bb9aa67927128bd3a0"
export INFRA_PARENT="c88320f1b2ac1995aa1d75f481e1f69d7063c2ba"
export CURRENT_MERGE="6717e4491d3e8a2d0b6fd6044a673041f30d040c"
export POST_MERGE_DOCS="b90bcc75dae48231a04e2efcedc51eb70dfac89c"

for object in "$APP_PARENT" "$INFRA_PARENT" "$CURRENT_MERGE" "$POST_MERGE_DOCS"; do
  test "$(git cat-file -t "$object")" = commit
done

test "$(git rev-list --parents -n 1 "$CURRENT_MERGE" | wc -w)" -eq 3
git merge-base --is-ancestor "$APP_PARENT" HEAD
git merge-base --is-ancestor "$INFRA_PARENT" HEAD

git show --no-patch --pretty=raw "$CURRENT_MERGE"
~~~

The raw merge output must show exactly these two parents, in this order:

~~~text
parent cc1fa07a617320a8efdf31bb9aa67927128bd3a0
parent c88320f1b2ac1995aa1d75f481e1f69d7063c2ba
~~~

Record PASS in the validation matrix. Do not attempt to restore the old IDs if
they are absent.

## 2. Run the local validation suite

Run all checks before opening a PR or changing cloud resources:

~~~bash
terraform fmt -check -recursive infrastructure terraform
terraform -chdir=infrastructure/environments/prod validate
helm lint k8s/helm/supply-chain-demo

helm template supply-chain-demo k8s/helm/supply-chain-demo \
  > /tmp/supply-chain-demo-rendered.yaml
kubectl apply --dry-run=client -f /tmp/supply-chain-demo-rendered.yaml

kubectl apply --dry-run=client -f policy/test-manifests
kubectl apply --dry-run=client -f policy/test-policies

bash policy/tests/check-identity-consistency.sh
~~~

Run the JMESPath test in an isolated temporary virtual environment if its
dependencies are not already installed:

~~~bash
VALIDATION_TMP="$(mktemp -d)"
python3 -m venv "$VALIDATION_TMP/venv"
"$VALIDATION_TMP/venv/bin/pip" install --quiet jmespath pyyaml
"$VALIDATION_TMP/venv/bin/python" policy/tests/test_jmespath_conditions.py
rm -rf "$VALIDATION_TMP"
~~~

Check formatting and secrets without printing sensitive values:

~~~bash
git diff --check
git ls-files | rg '(^|/)(terraform\.tfvars|.*\.tfstate|.*\.pem|.*\.key|kubeconfig)$' || true
git grep -nE 'https://discord\.com/api/webhooks/[0-9]+/' -- ':!plan.md' || true
~~~

The final two commands should produce no credential or webhook matches.

## 3. Verify the live deployment and exact digest

Derive the digest from the live Deployment instead of copying it from prose:

~~~bash
LIVE_IMAGE="$(kubectl -n default get deployment supply-chain-demo \
  -o jsonpath='{.spec.template.spec.containers[0].image}')"
LIVE_DIGEST="$(printf '%s' "$LIVE_IMAGE" | sed 's/^[^@]*@//')"
printf 'live image: %s\n' "$LIVE_IMAGE"
printf 'live digest: %s\n' "$LIVE_DIGEST"

gcloud artifacts docker images describe \
  "$GAR_REPOSITORY@$LIVE_DIGEST" \
  --project "$GCP_PROJECT" \
  --format='value(image_summary.digest)'

kubectl get nodes
kubectl -n argocd get application supply-chain-demo
kubectl -n kyverno get clusterpolicy block-unsigned-images
kubectl -n default get deployment supply-chain-demo
kubectl -n falco-system get daemonset falco
~~~

At the time this guide was written, the live chart and Deployment used:

~~~text
sha256:32a90d832fdf76794fa5477e42e1fdcec28c9eb6e0deee48ad466d1f7d9fc563
~~~

Some older prose files contain a different shortened/typo variant. Reconcile
those references using LIVE_DIGEST; never invent or manually alter a digest
without checking GAR.

## 4. Capture the real PR security gates

The PR workflow runs scans only when relevant paths change. A README-only PR is
not sufficient to prove Semgrep and Trivy.

### 4.1 Create a harmless relevant change

Start from the current remote main:

~~~bash
git switch main
git pull --ff-only origin main
git switch -c chore/validate-pr-security-gates
~~~

Make one harmless comment-only change in the retained test fixture
policy/test-manifests/test-invalid-trust.yaml. Do not change an image, policy
condition, workflow, or Terraform value. Then run:

~~~bash
git diff --check
git diff -- policy/test-manifests/test-invalid-trust.yaml
git add policy/test-manifests/test-invalid-trust.yaml
git commit -m "test: exercise pull request security gates"
git push --set-upstream origin chore/validate-pr-security-gates
~~~

### 4.2 Open and inspect the PR

Open a pull request from chore/validate-pr-security-gates into main using the
GitHub web UI or an authenticated gh pr create. Do not paste a token into shell
history or this guide.

Wait for these contexts to finish:

- PR Check / Detect relevant changes — relevant must be true.
- Security Scan / SAST (Semgrep) — successful with no blocking findings.
- Security Scan / Vulnerability Scan (Trivy) — successful with no blocking
  high/critical filesystem findings.
- Policy Unit Tests — successful.

Record the PR URL, run URL, run ID, commit SHA, and conclusions in
docs/codex/03-VALIDATION.md. Capture the PR page and each successful check for
the first personal evidence image.

If the change is not useful to keep, close the PR after recording evidence and
delete the temporary branch from GitHub and locally:

~~~bash
git switch main
git pull --ff-only origin main
git branch -D chore/validate-pr-security-gates
git push origin --delete chore/validate-pr-security-gates
~~~

Never use a force push for cleanup.

## 5. Reconcile documentation deliverables

The original plan names a few deliverables that currently have Codex-specific
equivalents. To satisfy the literal plan, create the root-level copies or
wrappers after reviewing their content:

~~~bash
cp docs/codex/09-RESUME-MATERIAL.md docs/RESUME.md
cp docs/codex/10-INTERVIEW-GUIDE.md docs/INTERVIEW-PREP.md
~~~

Then update README evidence links to point to the root files, or keep both links
if the Codex tracking versions are useful.

Also correct these closeout details:

1. Use the exact planned title GCP Software Supply Chain & Runtime Security if
   that title is required for the portfolio.
2. Replace any prose digest that differs from LIVE_DIGEST after verifying it
   against GAR.
3. In docs/codex/03-VALIDATION.md, set the final documentation commit to the
   actual commit containing the final documentation, not an earlier deploy or
   fixture commit.
4. Preserve upstream names only as historical attribution; active trust values
   must remain devSatym/gcp-supply-chain-security.
5. Do not edit historical evidence merely to make it look current.

Run the local validation suite again after documentation changes.

## 6. Capture personal evidence

Do not relabel docs/evidence/; those files are historical upstream evidence.
Save only screenshots from this deployment under docs/my-validation/. Remove
account email addresses, tokens, webhook URLs, private IPs, and unnecessary
project metadata before committing.

Capture the following files, matching the original plan:

| File | Evidence to show |
| --- | --- |
| 01-pr-security-gates.png | PR page with Semgrep, Trivy, and policy checks passed |
| 02-main-build-pipeline.png | Successful build, image push, sign, attest, and verify jobs |
| 03-gar-image-digest.png | Immutable GAR image digest and separate Cosign metadata repository |
| 04-cosign-verification.png | Canonical signer, GitHub OIDC issuer, Rekor, and digest verification |
| 05-sbom-provenance-verification.png | SPDX and SLSA predicate verification, builder, source, and entrypoint |
| 06-gke-workloads.png | Ready node, Kyverno, Argo CD, Falco, and application workloads |
| 07-argocd-healthy.png | supply-chain-demo Synced/Healthy, canonical repo URL, and Helm path |
| 08-trusted-image-admitted.png | Trusted digest server dry-run and running replicas |
| 09-unsigned-image-blocked.png | Kyverno denial containing no signatures found |
| 10-invalid-provenance-blocked.png | Wrong signer and wrong source URI denial |
| 11-init-container-bypass-blocked.png | Signed main container plus unsigned init-container denial |
| 12-falco-runtime-detection.png | CRITICAL custom Falco shell rule with timestamp |
| 13-runtime-alert.png | Actual Discord notification, only if alerting is enabled and received |

Command examples for evidence capture:

~~~bash
kubectl get nodes
kubectl get pods -A
kubectl -n argocd get application supply-chain-demo -o wide
kubectl -n kyverno get clusterpolicy block-unsigned-images -o wide
kubectl -n default get deployment supply-chain-demo -o wide
kubectl -n falco-system get pods -o wide
kubectl -n default logs deployment/supply-chain-demo --tail=50
kubectl -n falco-system logs daemonset/falco --since=15m
~~~

For admission evidence, use the committed fixtures. Apply negative test
policies only for the duration of the test and delete any temporary
ClusterPolicy afterward. Never configure an intentionally invalid fixture as an
automated Argo CD application.

## 7. Optional: enable and prove Discord alerting

This section is required only if end-to-end runtime notification is part of
the portfolio definition. The current project correctly leaves it disabled
until a real webhook exists.

### 7.1 Supply the webhook safely

Create the webhook in Discord privately. Do not send it in chat, commit it, or
put it in a command argument that will enter shell history. Edit the ignored
file infrastructure/environments/prod/terraform.tfvars:

~~~hcl
enable_runtime_alerting = true
discord_webhook_url     = "https://discord.com/api/webhooks/<REAL_VALUE>"
~~~

Confirm it is ignored before running Terraform:

~~~bash
git check-ignore -v infrastructure/environments/prod/terraform.tfvars
git status --short
~~~

The webhook must not appear in git diff, git status, Terraform logs, or
screenshots.

### 7.2 Plan and apply only the reviewed alerting change

From the prod root:

~~~bash
terraform -chdir=infrastructure/environments/prod plan \
  -input=false \
  -out=/tmp/falco-alerting.tfplan
terraform -chdir=infrastructure/environments/prod show \
  -no-color /tmp/falco-alerting.tfplan \
  | rg 'falco_alerting|falcosidekick|pubsub|discord|secret|function'
~~~

The plan should add only the guarded Pub/Sub, Secret Manager, Cloud Function,
service-account, IAM, and Falcosidekick wiring. Review the complete plan; do
not apply if unrelated infrastructure changes appear.

~~~bash
terraform -chdir=infrastructure/environments/prod apply \
  -input=false /tmp/falco-alerting.tfplan
rm -f /tmp/falco-alerting.tfplan
~~~

The alert path must use the existing Workload Identity design:

~~~text
Falco → Falcosidekick KSA → GKE Workload Identity → Pub/Sub publisher
→ Cloud Function → Secret Manager webhook → Discord
~~~

Do not create a JSON service-account key as a fallback.

### 7.3 Validate every hop

~~~bash
kubectl -n falco-system get serviceaccount falco-falcosidekick -o yaml
kubectl -n falco-system logs deployment/falco-falcosidekick --since=15m
gcloud pubsub topics list --project "$GCP_PROJECT"
gcloud functions list --gen2 --region "$GCP_REGION" --project "$GCP_PROJECT"
gcloud functions logs read falco-discord-notifier \
  --gen2 --region "$GCP_REGION" --project "$GCP_PROJECT" --limit=50
~~~

Trigger the existing safe runtime event:

~~~bash
APP_POD="$(kubectl -n default get pods \
  -l app.kubernetes.io/name=supply-chain-demo \
  -o jsonpath='{.items[0].metadata.name}')"
kubectl -n default exec "$APP_POD" -- /bin/sh -c 'id'
~~~

Confirm all of the following, in order:

1. Falco emits Shell Spawned In Signed Workload Pod.
2. Falcosidekick accepts and publishes the event without PermissionDenied.
3. Pub/Sub receives and delivers the message.
4. The Cloud Function returns a successful Discord response.
5. The Discord channel receives the alert.

Capture 13-runtime-alert.png only after the notification is visibly received.
Do not claim V25 or the final runtime-alert checklist item before this point.

### 7.4 Decide whether to retain the alerting resources

If the project should remain demonstrable, retain the resources and record the
recurring cost. If the alert was only a test, set enable_runtime_alerting to
false, remove the webhook from the ignored tfvars file, run a reviewed
Terraform plan/apply, and verify the alerting resources are gone. Do not destroy
the entire project for this step.

## 8. Optional: activate GitHub main-branch protection

The root Terraform configuration already targets:

~~~text
owner:      devSatym
repository: gcp-supply-chain-security
~~~

Do this only after the PR run has proven the exact required status contexts:

~~~text
Policy Unit Tests
Security Scan / SAST (Semgrep)
Security Scan / Vulnerability Scan (Trivy)
~~~

With an administrator-authorized GITHUB_TOKEN available only in the current
shell:

~~~bash
terraform -chdir=terraform init -input=false
terraform -chdir=terraform validate
terraform -chdir=terraform plan -input=false -out=/tmp/github-ruleset.tfplan
terraform -chdir=terraform show -no-color /tmp/github-ruleset.tfplan
~~~

The plan should contain only the canonical repository ruleset. Apply it only
after reviewing the complete plan:

~~~bash
terraform -chdir=terraform apply -input=false /tmp/github-ruleset.tfplan
rm -f /tmp/github-ruleset.tfplan
unset GITHUB_TOKEN
~~~

Verify it in GitHub repository Settings → Rules → Rulesets. If the account
cannot apply rulesets or the check contexts are not available, leave the
ruleset unapplied and document that limitation; it must not block the core
project.

## 9. Final documentation and validation update

After the PR, screenshots, and optional alert decision, update these files:

- docs/codex/02-PROJECT-STATUS.md — remove completed items from Remaining work.
- docs/codex/03-VALIDATION.md — record PR run IDs, alert result, exact digest,
  and final documentation commit.
- docs/codex/05-HANDOFF.md — describe the actual final state and any explicit
  limitation.
- docs/codex/08-SCREENSHOT-CHECKLIST.md — mark only captured images as complete;
  keep alerting pending if it was not enabled.
- README.md — ensure every claim matches observed evidence.
- docs/RESUME.md and docs/INTERVIEW-PREP.md — if the literal plan paths are
  being satisfied.

Run the full final check:

~~~bash
git status --short
git diff --check
git diff --cached --check

terraform fmt -check -recursive infrastructure terraform
terraform -chdir=infrastructure/environments/prod validate
terraform -chdir=infrastructure/environments/prod plan -input=false
helm lint k8s/helm/supply-chain-demo
bash policy/tests/check-identity-consistency.sh
FINAL_VALIDATION_TMP="$(mktemp -d)"
python3 -m venv "$FINAL_VALIDATION_TMP/venv"
"$FINAL_VALIDATION_TMP/venv/bin/pip" install --quiet jmespath pyyaml
"$FINAL_VALIDATION_TMP/venv/bin/python" policy/tests/test_jmespath_conditions.py
rm -rf "$FINAL_VALIDATION_TMP"

git merge-base --is-ancestor "$APP_PARENT" HEAD
git merge-base --is-ancestor "$INFRA_PARENT" HEAD
~~~

Before committing, inspect both staged and unstaged changes explicitly:

~~~bash
git status --short
git diff
git diff --cached
~~~

Stage only the intended documentation/evidence files. Never use git add -A
while plan.md is untracked.

~~~bash
git add README.md docs/codex docs/my-validation docs/RESUME.md docs/INTERVIEW-PREP.md
git diff --cached --check
git diff --cached --stat
git commit -m "docs: complete project closeout evidence"
git push origin main
~~~

Confirm the local and remote tips match:

~~~bash
git rev-parse HEAD origin/main
git status -sb
~~~

The only remaining worktree entry may be the intentionally untracked plan.md.

## 10. Evidence retention and cleanup

Do not delete the unsigned fixture until its denial screenshot and validation
record are complete. When ready, delete only the disposable GAR version:

~~~bash
export UNSIGNED_DIGEST="sha256:18549c45e5d1d87804372cb8082cefbee1019b9c592d816d14817cc12472ca17"
gcloud artifacts docker images describe \
  "$GAR_REPOSITORY@$UNSIGNED_DIGEST" \
  --project "$GCP_PROJECT"
~~~

After reviewing that output and confirming the evidence is retained:

~~~bash
gcloud artifacts docker images delete \
  "$GAR_REPOSITORY@$UNSIGNED_DIGEST" \
  --project "$GCP_PROJECT" \
  --quiet
~~~

If a negative-test Argo Application was ever applied, remove it after testing:

~~~bash
kubectl -n argocd delete application supply-chain-test-negative --ignore-not-found
~~~

Keep the trusted image, signature metadata, SBOM, and provenance until the
portfolio evidence is archived. Review GKE, Cloud NAT, disks, GAR storage,
logging, and any alerting resources as the main cost drivers.

Only with explicit approval should you perform a full teardown. First run a
destroy plan, inspect every resource, and confirm the state bucket and evidence
retention plan before applying it.

## Completion checklist

Mark an item complete only when its evidence is stored or its command output is
recorded:

- [ ] Current canonical merge and both parent ancestry checks pass.
- [ ] docs/repository-merge.md uses the current canonical hashes.
- [ ] Terraform fmt, validate, and final no-drift plan pass.
- [ ] GKE, GAR, WIF, Kyverno, Argo CD, and Falco are healthy.
- [ ] A real PR proves Semgrep, Trivy, and policy checks.
- [ ] Main-branch build, GAR digest, Cosign, SPDX, SLSA, and verification are
      recorded.
- [ ] Trusted, unsigned, wrong-trust, and init-container admission outcomes
      are recorded.
- [ ] Falco controlled runtime detection is recorded.
- [ ] Discord alert is either end-to-end validated or explicitly accepted as a
      documented limitation.
- [ ] Personal screenshots are stored under docs/my-validation/ and redacted.
- [ ] README title, digest references, and claims match live evidence.
- [ ] Literal resume/interview files exist if required by the original plan.
- [ ] No secrets, state, keys, or webhook URLs are tracked.
- [ ] Only intended documentation/evidence changes are committed and pushed.
- [ ] Unsigned test artifact and live infrastructure have an explicit retention
      or cleanup decision.

When every required item is checked, update the handoff to READY — COMPLETE.
If Discord or ruleset activation is intentionally omitted, record that as a
scoped limitation rather than claiming those phases passed.
