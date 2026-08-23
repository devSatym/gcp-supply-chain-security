# CI / DevSecOps Pipeline Audit

Audit date: 2026-08-23
Canonical repository: devSatym/gcp-supply-chain-security
Audit method: plan.md intended state compared with active executable workflows,
composite actions, Terraform/WIF, Helm, Argo CD, Kyverno, and observed GitHub
Actions runs.

## Executive result

The active pipeline has eight root workflows. Its pull-request design is
deliberately unprivileged: it runs relevant-change detection, Semgrep, Trivy
filesystem scanning, policy tests, and a local built-image Trivy scan, but does
not authenticate to GCP, push to GAR, sign, attest, update Git, or deploy.

The main-branch chain is build and push -> Trivy scan by immutable digest ->
Cosign keyless signing -> SPDX SBOM attestation -> SLSA provenance attestation
-> verification. A successful main run, 32630716371, proves all of those
stages for the deployed digest's source run. The hardened main run
32638968765 subsequently passed Build and Push, final Trivy, Sign and Attest,
and the stricter Verify job for merge commit 27a94b0.

There is no evidence of a pull_request_target workflow, a CI JSON
service-account key, a write-all permission, or a PR path to GCP Workload
Identity Federation. The observed skipped production jobs on a PR are expected
security controls, not failed gates. The current workflow split removes those
inapplicable jobs from the PR UI altogether: Deploy is main/manual only and
PR Image Scan runs under PR Check.

Two workflow fixes were implemented and validated:

1. Verify now fails closed unless the provenance predicate, builder, source
   URI, source commit, workflow entrypoint, and subject digest match.
2. A manually dispatched trusted build now requires refs/heads/main as well
   as the typed confirmation.

Two controls remain outside this change set:

1. No active IaC/misconfiguration security gate exists. The current Trivy
   filesystem scan defaults to vulnerability and secret scanners; it does not
   select the misconfiguration scanner.
2. The repository has no active GitHub ruleset even though Terraform defines
   one. Applying branch protection can affect recovery and requires explicit
   user approval.

## Sources reviewed

- plan.md was read completely and is the intended-state source.
- README.md and docs/codex/00 through 05 were read as current documentation.
- Every file under .github/workflows and .github/actions was read.
- The preserved non-active workflow under infrastructure/.github/workflows was
  read and classified separately.
- Terraform WIF resources, policy/kyverno/block-unsigned-images.yaml, both
  Argo Applications, Helm values/template, policy tests, Git history for the
  pinned digest, live WIF provider configuration, GAR metadata, and GitHub
  Actions run metadata were inspected.

Executable files determine current behavior. plan.md determines whether that
behavior meets the intended project security controls.

## Workflow inventory

| Workflow | File | Trigger | PR | Push main | Manual | Paths | Permissions | Produces artifact? | Pushes artifact? | Security purpose |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PR Check | .github/workflows/pr-check.yml | pull_request to main | Yes | No | No | Workflow always starts; jobs use an in-workflow relevant-path filter | contents: read; security-events: write; pull-requests: read | SARIF reports and a local PR image | No | PR SAST, filesystem scan, policy tests, and built-image scan |
| Deploy | .github/workflows/deploy.yml | push to main; workflow_dispatch | No | Yes | Yes, typed confirm on canonical main only | Push paths: app, Dockerfile, .dockerignore, root workflows/actions. | contents: read; id-token: write; security-events: write | GAR image and attestations | Main/manual only | Orchestrates trusted build, scan, sign, attest, and verify |
| Build and Push | .github/workflows/build-push.yml | workflow_call only | Called only from trusted Deploy job | Called from Deploy | Called from Deploy | Caller-controlled | contents: read; security-events: write; id-token: write | Docker image, digest output, SARIF | When push input is true | WIF auth, GAR build/push, final immutable-image scan |
| Sign and Attest | .github/workflows/sign-attest.yml | workflow_call only | Not independently runnable | Called after build | Called after build | Caller-controlled | contents: read; id-token: write | SPDX JSON artifact, signature, two attestations | Cosign metadata only | Keyless signature, SPDX SBOM, SLSA provenance |
| Verify Attestations | .github/workflows/verify.yml | workflow_call only | Not independently runnable | Called after sign | Called after sign | Caller-controlled | contents: read; id-token: write | Job summary | No | Signature, SBOM, and provenance verification |
| Security Scan | .github/workflows/security-scan.yml | workflow_call only | Called by PR Check | No | No | Caller-controlled relevant output | contents: read; security-events: write | Semgrep and Trivy SARIF | No | Reusable blocking PR security scans |
| SBOM and VEX | .github/workflows/sbom-vex.yml | workflow_call only | Not run | Called in parallel with build | Called in parallel with build | Caller-controlled | contents: read | CycloneDX SBOM and reachability report artifacts | No | Supplementary non-blocking dependency/reachability evidence |
| Infrastructure Terraform | .github/workflows/infrastructure-terraform.yml | PR/push main/manual | Yes | Yes | Yes | infrastructure/** for PR/push | contents: read | No | No | Terraform format, offline init, and validate only |

### Preserved workflow that is not active

infrastructure/.github/workflows/terraform.yml is an imported upstream
artifact. GitHub does not activate workflows below infrastructure/.github.
It contains old mutable action tags, old path assumptions, non-blocking format
and Checkov behavior, WIF secrets, PR comment access, and an apply job. It
does not run in this monorepo and must not be treated as current CI. It remains
preserved for history/provenance. .semgrepignore excludes only this inactive
file; all active root workflow files remain in Semgrep scope.

## Job inventory and authority analysis

All active jobs use no GitHub environment. There is no active job with
contents: write, packages: write, write-all, a deploy environment, kubectl,
Terraform apply, git commit, or git push.

| Workflow / job | Needs, condition, and path behavior | Permissions, credentials, environment | Inputs, outputs, artifacts | PR/main/manual behavior and mutation authority |
| --- | --- | --- | --- | --- |
| PR Check / changes | No needs or if. Always starts for a PR. dorny/paths-filter emits relevant based on application, CI, policy, Terraform, infrastructure, and Helm paths. | Workflow permissions; GitHub read token only. No environment. | Output: relevant. No artifact. | PR only. Cannot mutate GCP, GAR, Git, or deployment. |
| PR Check / security-scan | Needs changes. Calls Security Scan with fail-on-findings true and run-scan equal to relevant. | Callee has contents read and security-events write. No WIF, secrets, or environment. | SARIF uploaded by callee. | PR only. Can submit code-scanning SARIF, not Git/GCP/GAR/sign/deploy. |
| PR Check / policy-test | Needs changes; runs only when relevant is true. | contents read through workflow token. No WIF, secrets, or environment. | No output/artifact. Runs identity-consistency shell test and JMESPath test. | PR only. No mutation authority. |
| PR Check / pr-image-scan | Needs changes; runs only when relevant is true. | PR Check permissions: contents read, security-events write, pull-requests read. No id-token, WIF, secrets, or environment. | Local image named supply-chain-demo:pr-SHA and trivy-image.sarif. | PR only. Builds locally, never pushes GAR, signs, attests, modifies Git, or deploys. |
| Security Scan / semgrep | Called job; if run-scan. | contents read, security-events write. Pinned Semgrep container; no cloud auth. | semgrep.sarif, category semgrep. | PR caller only. No GCP/GAR/sign/attest/Git/deploy authority. |
| Security Scan / trivy | Called job; if run-scan. | contents read, security-events write. No cloud auth. | trivy.sarif, category trivy-fs. | PR caller only. No GCP/GAR/sign/attest/Git/deploy authority. |
| Deploy / build-push | If ref is refs/heads/main and the event is push or manual confirm equals deploy. | Caller supplies GAR/WIF variables to reusable workflow. No environment. | Delegated digest output from callee. | Not invoked on PR or non-main manual refs. Main-only trusted artifact operation; can authenticate to GCP and push GAR. Cannot modify Git or deploy. |
| Deploy / sbom-vex | Same canonical-main event condition as build-push; no needs. | contents read only in callee. | CycloneDX and report artifacts. | Not invoked on PR or non-main manual refs. Main-only. No GCP, GAR, signing, Git, or deployment mutation. |
| Deploy / sign-attest | Needs build-push and explicitly requires refs/heads/main. A skipped/failed need prevents it. | Calls callee with WIF/GAR/Cosign variables. | No caller output. | Not invoked on PR or non-main refs. Main-only; can access GAR, sign, and attest. Cannot modify Git or deploy. |
| Deploy / verify | Needs build-push and sign-attest and explicitly requires refs/heads/main. A skipped/failed need prevents it. | Calls callee with WIF/GAR/Cosign variables. | Verification summary. | Not invoked on PR or non-main refs. Main-only; reads GAR/Cosign metadata. Cannot sign, modify Git, or deploy. |
| Build and Push / build | No needs; invoked only by Deploy. Trivy step runs only if push input is true. | contents read, security-events write, id-token write. GCP Auth uses GitHub OIDC and WIF. No environment. | Output: steps.build.outputs.digest. Image tag uses github.sha; SARIF category trivy-image. | Main/manual caller only. Can authenticate to GCP and push GAR; cannot sign, attest, modify Git, or deploy. |
| Sign and Attest / sign-attest | No needs; invoked after Build and Push. | contents read, id-token write. GCP Auth, Cosign keyless OIDC, Syft. No environment. | sbom.spdx.json upload artifact; Cosign signature; SPDX and SLSA attestations. | Main/manual caller only. Can authenticate to GCP, sign, and attest. Cannot modify Git or deploy. |
| Verify / verify | No needs; invoked after Build and Sign. | contents read, id-token write. GCP Auth and Cosign. No environment. | Step summary with verification fields. | Main/manual caller only. Reads registry and Sigstore data. Cannot sign, modify Git, or deploy. |
| SBOM and VEX / cdxgen | No needs; parallel caller job. | contents read only. Dockerized cdxgen and depscan. No environment. | bom.cdx.json and reports artifact. | Main/manual caller only. No GCP/GAR/sign/attest/Git/deploy authority. |
| Infrastructure Terraform / validate | Matrix for vpc, gke, kubernetes-addons, falco, falco-alerting, environments/prod. No needs or if. PR/push scoped to infrastructure/**. | contents read only. No credentials or environment. | No outputs/artifacts. | Runs on matching PR/push or manual. Format/init backend=false/validate only; no cloud mutation, apply, GAR, sign, Git, or deployment. |

## Event matrix

Cells use the requested status vocabulary only. Path-qualified rows run only
when their documented relevant paths change.

| Capability | Pull Request | Push to main | workflow_dispatch |
| --- | --- | --- | --- |
| relevant change detection | RUNS | NOT APPLICABLE | NOT APPLICABLE |
| Semgrep SAST | RUNS | NOT APPLICABLE | NOT APPLICABLE |
| Trivy filesystem scan | RUNS | NOT APPLICABLE | NOT APPLICABLE |
| Terraform security/IaC scan | MISSING | MISSING | MISSING |
| Kubernetes/config security scan | MISSING | MISSING | MISSING |
| policy tests | RUNS | NOT APPLICABLE | NOT APPLICABLE |
| Docker build | RUNS | RUNS | RUNS |
| PR image scan | RUNS | NOT APPLICABLE | NOT APPLICABLE |
| GAR authentication | NOT APPLICABLE | RUNS | RUNS |
| GAR push | NOT APPLICABLE | RUNS | RUNS |
| Trivy final image scan | NOT APPLICABLE | RUNS | RUNS |
| Cosign keyless signing | NOT APPLICABLE | RUNS | RUNS |
| SPDX SBOM generation | NOT APPLICABLE | RUNS | RUNS |
| SBOM attestation | NOT APPLICABLE | RUNS | RUNS |
| SLSA provenance generation | NOT APPLICABLE | RUNS | RUNS |
| provenance attestation | NOT APPLICABLE | RUNS | RUNS |
| signature verification | NOT APPLICABLE | RUNS | RUNS |
| SBOM verification | NOT APPLICABLE | RUNS | RUNS |
| provenance verification | NOT APPLICABLE | RUNS | RUNS |
| desired-state digest update | SKIPPED BY DESIGN | SKIPPED BY DESIGN | SKIPPED BY DESIGN |
| Argo/GitOps deployment | NOT APPLICABLE | NOT APPLICABLE | NOT APPLICABLE |

### Matrix explanations

- PR GAR/WIF/push/sign/attest/verify rows are not applicable: Deploy does not
  trigger on a PR. This avoids creating misleading skipped check rows while
  keeping all production artifact authority on trusted main code.
- The manual row represents Deploy with an explicit confirm input on
  refs/heads/main. The implemented CI-002 guard prevents a manually selected
  feature branch from reaching WIF/GAR/signing authority.
- Desired-state pinning is intentionally manual: plan.md phase 29 specifies
  updating Helm values with a verified digest after the pipeline succeeds.
  No workflow writes Git. The exact current pin is traceable to a successful
  signed/verified run, so this is a manual promotion model rather than an
  automatic GitOps updater.
- Argo CD is an external continuous controller. GitHub Actions does not call
  Argo or kubectl; Argo reconciles a digest that is already committed to the
  canonical repository.
- Infrastructure Terraform validation does run on matching changes, but it is
  validation rather than an IaC security scan. That is why the two security
  scan rows are MISSING.

## Pull-request pipeline assessment

### Why Deploy does not appear on a PR

Deploy triggers only on a push to main or a manually confirmed main dispatch.
PR Image Scan is now a PR Check job:

    Detect relevant changes           runs
    Semgrep                           runs for relevant changes
    Trivy filesystem                  runs for relevant changes
    Policy Unit Tests                 runs for relevant changes
    PR Image Scan                     runs for relevant changes

The refactor keeps the same trivy-image SARIF category that resolved the
GitHub code-scanning configuration mismatch. It removes misleading skipped
production-job rows without granting a PR access to GCP, GAR, signing, or
attestation authority.

### PR Image Scan

The job builds the root Dockerfile with Docker Buildx, passes the current
commit SHA as GIT_SHA, loads the image locally, and tags it
supply-chain-demo:pr-SHA. It runs Trivy image scanning at CRITICAL,HIGH with
exit-code 1, SARIF output, severity-limited SARIF, and .trivyignore. It does
not invoke GCP Auth, use WIF, push to GAR, sign, generate attestations, update
Git, or call a deployment tool.

This complements, rather than duplicates, the filesystem scan:

- Trivy filesystem scan examines repository dependencies/files and secrets.
- Built-image Trivy examines the actual final image layers, OS packages, and
  image configuration that would be published on main.

Observed evidence: PR 1, commit 1ce7d82, passed PR Image Scan in run
32636629034 and passed PR Check in run 32636629041.

### Semgrep

The exact command is:

    semgrep scan --config auto --error --sarif --output semgrep.sarif .

It scans the repository root with Semgrep auto rules and the sole active
exclusion is the retained inactive nested upstream Terraform workflow.
SARIF is uploaded under category semgrep.

Run Semgrep intentionally has continue-on-error so findings can be logged and
uploaded. Enforce findings policy then checks the Semgrep step outcome and
exits 1 when fail-on-findings is true. Therefore a Semgrep finding or scanner
error cannot turn the required job green. No Semgrep-specific || true, exit 0,
or set +e bypass exists.

### Trivy

| Use | Target / mode | Gate behavior | Reporting and ignores |
| --- | --- | --- | --- |
| PR filesystem | scan-type fs at repository root | CRITICAL,HIGH; exit code 1 | SARIF category trivy-fs. No explicit scanners input. Pinned Trivy action defaults to Trivy 0.70, whose fs default is vuln,secret; ignore-unfixed defaults false and Trivy defaults to .trivyignore. |
| PR image | Local Buildx-loaded image | CRITICAL,HIGH; exit code 1 before any push | SARIF category trivy-image; explicitly passes .trivyignore. |
| Main final image | Exact GAR image@BuildxDigest after push | CRITICAL,HIGH; exit code 1 before signing | SARIF category trivy-image; explicitly passes .trivyignore. |
| Terraform/IaC | None active | No gate | MISSING. |
| Kubernetes/config | None active | No gate | MISSING. |

The Trivy action never uses continue-on-error. SARIF upload uses always only
to retain results after a blocking scan failure; it cannot make the scan pass.

A direct audit test with Trivy 0.74 config scanning confirmed that the
repository has a real configuration baseline to resolve before enabling a
blocking gate: it reports GCP-0048 and GCP-0061 against the GKE module plus
deliberately insecure negative-test fixtures. The active action's Trivy 0.70
also panicked when its fs command was explicitly switched to misconfig over the
whole repository. Adding a blind blocking config scan would therefore create an
unreviewed failure mode, not a trustworthy gate.

### Why two scanner names appear on a PR

Security Scan / SAST (Semgrep) and Security Scan / Vulnerability Scan (Trivy)
are the blocking workflow jobs. Semgrep OSS and Trivy are GitHub Code Scanning
check runs generated when those same jobs upload SARIF. They are reporting
results from one scanner execution each, not duplicate scanner executions.
The code-scanning checks should be retained.

## Terraform CI assessment

The active Infrastructure Terraform workflow is appropriate for safe PR and
main validation:

    terraform fmt -check -recursive
    terraform init -backend=false -input=false
    terraform validate -no-color

It runs in each active module directory and never applies infrastructure. No
WIF, cloud credentials, plan with a live backend, or Terraform apply runs from
the active root workflow. This satisfies the minimum non-mutating Terraform CI
expectation. It does not provide static IaC/misconfiguration coverage, which
is tracked as a separate gap.

## Permissions and untrusted-PR security

No active workflow uses pull_request_target, workflow_run, repository_dispatch,
write-all, contents: write, packages: write, or an unpinned root action.

For a same-repository PR, fork PR, or Dependabot PR:

- PR Check has a read token plus security-events upload capability. It cannot
  access id-token or cloud credentials.
- PR Check / PR Image Scan inherits only contents read, security-events write,
  and pull-requests read. It cannot request a GitHub OIDC token.
- GCP Auth appears only in reusable workflows reached by the main/manual
  production path. Those caller jobs do not run for pull_request.
- No PR job consumes a GCP service-account JSON key, repository secret,
  write-capable Git token, or production deployment credential.

The code is therefore SAFE for untrusted PR credential exposure. A fork-specific
live run has not been captured; that is an evidence limitation, not a code path
that grants privilege.

## WIF and GAR assessment

The active GCP Auth composite action calls google-github-actions/auth with a
Workload Identity Provider and service-account input, then configures the GAR
Docker host with gcloud. It contains no credentials_json or key-file input.

Terraform and the live provider agree on the canonical repository condition:

    assertion.repository == 'devSatym/gcp-supply-chain-security'

The live provider maps assertion.repository to attribute.repository and uses
the GitHub Actions issuer. The CI service account has repository-level
Artifact Registry writer access for the application and Cosign metadata
repositories; Kyverno uses a distinct read-only verifier identity.

The CLI token used for this audit was not permitted to list repository
variables, so their values were not reprinted. Successful GCP-authenticated
main runs prove the variables consumed by Deploy are configured and usable.

## Trusted artifact trace

    github.sha
        -> Deploy passes image-tag to Build and Push
        -> Buildx tags GAR image with github.sha
        -> steps.build.outputs.digest
        -> jobs.build.outputs.digest
        -> Deploy needs.build-push.outputs.digest
        -> Trivy scans GAR image at immutable @digest
        -> Sign and Attest signs and attests that same @digest
        -> Verify verifies that same @digest
        -> operator manually commits that verified digest in Helm values
        -> Argo CD reconciles Helm
        -> Kyverno verifies the pinned digest before Pod admission

Current Helm values use an immutable digest, never latest:

    sha256:32a90d832fdf76794fa5477e42e1fdcec28c9eb6e0deee48ad466d1f7d9fc563

GAR confirms this digest is tagged by source commit e369771. The corresponding
manual trusted run 32629860698 completed build, final image scan, signing,
SBOM, provenance, and verification. Commit 9bf574 then manually pinned that
verified digest in Helm values. A newer main build may produce a newer verified
artifact without changing desired state; that is the documented manual
promotion model, not a mutable-tag deployment bypass.

The current main sequence is:

    build and push -> Trivy scan by digest -> sign/attest -> verify

Pushing before scanning leaves an unsigned registry version temporarily
available, but it cannot satisfy Kyverno because it is neither signed nor
attested. It is scanned by exact digest before any signing/attestation action.

## Cosign, SBOM, provenance, and verification

Sign and Attest uses GitHub OIDC with Cosign keyless commands and no Cosign
private key. It signs the exact immutable image reference. There is no
insecure-ignore-tlog option; both CI verification and Kyverno use the normal
Rekor-backed keyless verification path.

Syft generates SPDX JSON for the same image digest. Cosign attaches it with
type spdxjson. The supplementary CycloneDX/VEX workflow is separate and is not
the deployed SBOM trust artifact.

The provenance predicate is SLSA v0.2 and includes:

- builder: https://github.com/actions/runner
- source URI: git+https://github.com/devSatym/gcp-supply-chain-security@refs/heads/main
- material commit SHA
- entrypoint derived from the OIDC job_workflow_ref claim
- type: slsaprovenance

Kyverno checks the expected signer identity, issuer, Rekor, SPDX predicate,
SLSA predicate, builder, entrypoint, source URI, GAR scope, and verifyDigest.
The hardened CI Verify workflow independently fails closed unless the signature
has the expected immutable digest; the SPDX attestation has the correct
predicate and subject digest; and the SLSA provenance has the expected
predicate, subject digest, builder, entrypoint, source URI, source commit, and
material source/commit.

## Dependency and bypass analysis

    Build and Push
        -> Sign and Attest
            -> Verify

SBOM and VEX runs in parallel and is intentionally supplementary/non-blocking.
No deployment or Git desired-state promotion job exists in this workflow.

Sign and Attest has needs: build-push. Verify has needs: build-push and
sign-attest. Neither has an always condition that bypasses failed needs. The
only active always conditions are SARIF/report uploads; they preserve evidence
after a failing scanner and do not alter a prior failed result.

The non-blocking depscan workflow uses continue-on-error and || true by
design. It is not the SPDX SBOM, SLSA provenance, signature, or verification
gate required for admission.

## GitOps, Argo CD, and Kyverno consistency

| Trust dimension | CI producer | Admission consumer | Result |
| --- | --- | --- | --- |
| GAR image scope | Build and Push target GAR repository | Kyverno imageReferences | PASS |
| Image digest | Buildx digest output is passed to scan/sign/verify | Helm renders repository@digest; verifyDigest true | PASS |
| Keyless signer | Sign and Attest workflow | Kyverno subject sign-attest.yml at main | PASS |
| OIDC issuer / Rekor | Cosign keyless default verification | Kyverno issuer and Rekor URL | PASS |
| SPDX SBOM | Syft SPDX JSON; Cosign spdxjson attestation | Kyverno SPDX Document attestation | PASS |
| SLSA | Cosign slsaprovenance predicate | Kyverno SLSA v0.2 predicate | PASS |
| Builder / entrypoint / source | Provenance generator | Kyverno conditions | PASS in both CI verification and admission |
| Git source | Manual immutable digest commit | Argo canonical repo, main, Helm path | PASS |

The happy-path Argo Application points at the canonical repository, main, and
k8s/helm/supply-chain-demo with automated prune and self-heal. The negative
Application points at the canonical repository but has no automated sync, so
intentionally invalid resources are not continuously retried.

## Determination of former skipped PR jobs

### Deploy / Build and Push

STATUS: NOT APPLICABLE
SECURITY REASON: A PR must not receive GCP WIF or GAR push authority.
PLAN.MD REQUIREMENT: Build and publish trusted artifacts after main, not from
untrusted PR code.
ACTION: Deploy is not PR-triggered; keep it main/manual only.

### Deploy / SBOM and VEX (non-blocking)

STATUS: NOT APPLICABLE
SECURITY REASON: This supplementary CycloneDX/reachability job is not a PR
trust artifact and does not need privileged publication.
PLAN.MD REQUIREMENT: VEX enforcement is outside final deployment scope; the
required SPDX SBOM is generated in the trusted sign/attest path.
ACTION: Deploy is not PR-triggered; keep it main/manual only.

### Deploy / Sign and Attest

STATUS: NOT APPLICABLE
SECURITY REASON: A PR must not create a trusted Cosign signature or
attestation that could later meet admission expectations.
PLAN.MD REQUIREMENT: Keyless signing and attestations are main-only trusted
operations.
ACTION: Deploy is not PR-triggered; keep it main/manual only.

### Deploy / Verify

STATUS: NOT APPLICABLE
SECURITY REASON: It depends on a trusted pushed/signed artifact and has
nothing safe to verify on a local-only PR image.
PLAN.MD REQUIREMENT: Verification follows the main artifact trust chain.
ACTION: Deploy is not PR-triggered; keep it main/manual only.

## Implementation result and follow-up plan

Completed:

1. CI-002: added refs/heads/main guards to privileged Deploy callers and their
   dependent Sign and Verify jobs. A manual dispatch must now select main and
   supply the typed confirmation.
2. CI-001: added fail-closed signature, SPDX, and SLSA contract assertions to
   Verify. Exact certificate identity matching replaces the earlier regular
   expression matching.
3. Moved PR Image Scan into PR Check and made Deploy main/manual only. The
   PR now exposes only applicable unprivileged gates while preserving the
   Trivy image SARIF category and zero PR cloud authority.
4. Validated the earlier hardening through PR #2 and main run 32638968765;
   the screenshot PR validates the UI-focused split.

Follow-up:

1. Do not enable a blocking IaC/config scan until an owned baseline exists.
   Resolve or scope the GKE findings and intentionally insecure negative
   fixture paths, then introduce a version-pinned, fail-closed scanner.
2. Do not apply the defined GitHub main ruleset without explicit user approval,
   because it is a branch-protection change with recovery implications.

## Observed run evidence

| Event | Run | Result | Evidence |
| --- | --- | --- | --- |
| Real relevant PR | 32636629041 | SUCCESS | Detect relevant changes, policy tests, Semgrep, Trivy |
| Real PR local image | 32636629034 | SUCCESS | PR Image Scan in the earlier combined workflow |
| Previous main trusted chain | 32630716371 | SUCCESS | Build/push, final Trivy, sign/attest, verify, supplementary SBOM/VEX |
| Hardened relevant PR | 32638905514 and 32638905554 | SUCCESS | PR #2 passed Semgrep, Trivy filesystem, policy tests, and PR Image Scan in the earlier combined workflow |
| Hardened main trusted chain | 32638968765 | SUCCESS | Build/push, final Trivy, keyless sign, SPDX/SLSA attestations, strict signature/SBOM/provenance Verify, and supplementary SBOM/VEX all passed for 27a94b0; verified digest a0073f8f1d73f62ab0a15634a48387e78f6f837cff80f27a5c6e3b0a5c1eb16a |
