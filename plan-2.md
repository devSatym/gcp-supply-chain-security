You are working inside the repository:

gcp-supply-chain-security

Your task is to completely redesign and rewrite the ROOT `README.md` into a polished, detailed, technically credible, recruiter-friendly, interview-friendly DevSecOps project README.

This is NOT a generic documentation rewrite.

The README must accurately represent the ACTUAL implementation in this repository and the ACTUAL live evidence already captured under:

docs/my-validation/

The final README should make this project look like a serious end-to-end DevSecOps / software supply-chain security project while remaining technically honest.

Do not exaggerate.
Do not invent components.
Do not claim anything that cannot be supported by repository code, workflows, Terraform, policies, manifests, validation docs, or screenshots.

======================================================================
PRIMARY PROJECT POSITIONING
======================================================================

Use this project title:

# GCP Software Supply Chain & Runtime Security

Position it primarily as:

- DevSecOps
- Software Supply Chain Security
- Kubernetes Security
- GCP
- GitHub Actions
- GitOps
- Runtime Security

Do NOT position this as a platform-engineering project.

The core story should be:

Developer
  |
  +-- Pull Request Security Gates
  |     +-- Semgrep SAST
  |     +-- Trivy vulnerability/filesystem scan
  |     +-- Policy tests
  |     +-- Local PR image build/scan
  |
  +-- Trusted main branch
        |
        +-- GitHub Actions
              |
              +-- GitHub OIDC
              +-- GCP Workload Identity Federation
              |
              +-- Build image
              +-- Push to Artifact Registry
              +-- Final image scan
              +-- Keyless Cosign signing
              +-- SPDX SBOM
              +-- SLSA provenance
              +-- Supply-chain verification
                    |
                    +-- Git desired state
                          |
                          +-- Argo CD
                                |
                                +-- Kyverno admission control
                                |     +-- trusted signed image -> ADMIT
                                |     +-- unsigned image -> DENY
                                |     +-- incorrect identity/provenance -> DENY
                                |     +-- unsigned initContainer -> DENY
                                |
                                +-- GKE workload
                                      |
                                      +-- Falco runtime detection
                                      +-- Falcosidekick

The README must explain both:

1. Preventive security controls
2. Detective/runtime security controls

A reader should understand that:

- CI verifies code/artifacts before deployment.
- Cryptographic identity and attestations establish artifact trust.
- Argo CD reconciles trusted Git state.
- Kyverno enforces trust before workloads are admitted.
- Falco detects suspicious behavior after workload admission.

======================================================================
CRITICAL SAFETY / PRIVACY REQUIREMENTS
======================================================================

THE README MUST NOT LEAK SENSITIVE INFORMATION.

Before editing README.md, perform a repository-wide sensitive-information review of anything you plan to copy into the README.

Do NOT expose:

- access tokens
- GitHub tokens
- GCP credentials
- service-account private keys
- JSON service-account keys
- passwords
- webhook URLs
- Discord webhook URLs
- API keys
- authorization headers
- cookies
- kubeconfig credentials
- refresh tokens
- OIDC tokens
- private certificates
- private key material
- Terraform secret variables
- GitHub Actions secrets
- secret environment variable values
- personal phone numbers
- personal email addresses
- local machine usernames where unnecessary
- home-directory paths
- anything under `.git` that looks credential-related
- sensitive IDs that are unnecessary to explain the architecture

If an identifier is technically public/non-secret but unnecessary for the README,
prefer a generic placeholder such as:

<gcp-project-id>
<artifact-registry>
<github-repository>
<workload-identity-provider>

Do not copy my personal email address from Git history, Argo CD UI, workflow logs,
or screenshots into prose.

Do not print GitHub secret values.

Do not print GCP Workload Identity provider resource numbers unless absolutely necessary.

Do not print a Discord webhook.

Do not expose any credentials even if they accidentally exist in repository history.

If a screenshot already contains an ordinary non-secret identifier such as a public repository name or GCP project ID, that is not automatically a blocker.

However:

- inspect every screenshot before embedding it
- if any screenshot contains a REAL secret, credential, token, webhook, private key,
  password, or other sensitive authentication material:
    STOP embedding that screenshot
    record the issue
    tell me which screenshot needs redaction

Do not silently publish a screenshot containing authentication material.

At the end, perform a final README-specific secret/sensitive-data audit.

======================================================================
SOURCE OF TRUTH / AUDIT FIRST
======================================================================

DO NOT immediately rewrite README.md.

First audit the repository.

Read at minimum:

- current root README.md
- plan.md if present, but DO NOT edit plan.md
- docs/my-validation/README.md if present
- docs/my-validation/*
- docs/codex/*
- docs/RESUME.md if present
- docs/INTERVIEW-PREP.md if present
- docs/repository-merge.md if present

Inspect:

- .github/workflows/*
- .github/actions/*
- terraform/*
- infrastructure/*
- argocd/*
- k8s/*
- policy/*
- Dockerfile
- application source
- Helm chart
- Falco config
- Falcosidekick config
- Kyverno policies
- Argo CD Application
- CI workflows
- signing/attestation workflows
- validation/test manifests

Determine:

1. What is actually implemented.
2. What is currently live-tested.
3. What is only preserved legacy/upstream material.
4. What is optional.
5. What is not deployed.
6. Which documentation statements are stale.

Do not blindly trust old README text.

Prefer executable code + current workflows + current validation evidence.

======================================================================
IMPORTANT CURRENT PROJECT FACTS TO VERIFY
======================================================================

Verify these against the repo before using them.

The current implementation is expected to include:

- GCP
- Terraform
- GKE
- Artifact Registry
- GitHub Actions
- GitHub OIDC
- GCP Workload Identity Federation
- Docker
- Semgrep
- Trivy
- Cosign/Sigstore keyless signing
- SPDX SBOM
- SLSA provenance
- Argo CD
- Helm
- Kyverno
- Falco
- Falcosidekick

The implementation intentionally focuses on:

software supply-chain security + admission security + runtime detection.

The README SHOULD NOT claim active use of tools merely because stale upstream code
or docs reference them.

Specifically verify before claiming deployment/use of:

- Gatekeeper
- Ratify
- cert-manager
- ExternalDNS
- Backstage
- Crossplane
- Argo Rollouts
- Prometheus
- Grafana
- Loki
- Tempo
- OpenTelemetry
- Vault
- service mesh
- multi-environment production platform features

If those are not part of the actual deployed path, do not present them as active project components.

======================================================================
GIT HISTORY / UPSTREAM ATTRIBUTION
======================================================================

This repository was formed from earlier upstream/application and infrastructure work.

Do not falsely imply that every historical commit or every imported component was authored from scratch in this repository.

If attribution/history is discussed:

- state it neutrally
- preserve upstream attribution where appropriate
- do not over-focus on Git history
- do not clutter the README with merge SHA details

Repository-history validation can stay in technical documentation.

The main README should focus on the project itself.

======================================================================
README GOALS
======================================================================

The README should be impressive enough that:

1. A recruiter can understand the value in 60 seconds.
2. A DevOps engineer can understand the architecture in 3–5 minutes.
3. An interviewer can inspect the security design in depth.
4. A technical reviewer can verify the claims using screenshots.
5. Someone can clone the repo and understand how it works.
6. It demonstrates that this is not simply “Docker + Kubernetes + CI/CD”.

The main differentiation should be:

- CI security gates
- identity-based keyless signing
- SBOM + provenance
- immutable digest deployment
- GitOps
- admission-time cryptographic verification
- bypass-resistant verification
- runtime threat detection
- real negative tests
- real live evidence

======================================================================
README DESIGN / STYLE
======================================================================

Make the README visually polished but professional.

Use:

- strong heading hierarchy
- short intro
- badges where meaningful
- architecture diagrams
- tables
- callouts
- collapsible details when useful
- code blocks
- evidence screenshots
- concise explanation directly below screenshots
- clear navigation / table of contents
- technical depth without becoming a textbook

Avoid:

- excessive emojis
- marketing fluff
- fake enterprise claims
- giant walls of text
- repeated explanations
- vague phrases like “enterprise-grade” unless concretely justified
- meaningless badges
- exaggerated performance numbers
- made-up metrics
- claiming production/customer usage
- saying “100% secure”
- saying “zero trust” unless accurately scoped and explained

Use a small number of tasteful icons/emojis only where they improve scanability.

======================================================================
OPENING SECTION
======================================================================

The first screen of README.md should be strong.

Recommended structure:

# GCP Software Supply Chain & Runtime Security

A concise 2–4 sentence explanation.

Explain something similar to:

This project implements a secure container delivery pipeline on GCP where trust is established before deployment and continuously checked at runtime.

Pull requests are scanned before merge. Trusted main-branch builds use GitHub OIDC and GCP Workload Identity Federation instead of long-lived cloud credentials. Images are scanned, keylessly signed, enriched with SPDX SBOM and SLSA provenance, verified, deployed through Argo CD by digest, enforced by Kyverno, and monitored by Falco at runtime.

Rewrite this naturally based on verified implementation.

Then include a compact stack/badge row.

Possible categories:

Cloud:
- GCP
- GKE
- Artifact Registry

IaC:
- Terraform

CI / Supply Chain:
- GitHub Actions
- Semgrep
- Trivy
- Cosign
- Sigstore
- SPDX
- SLSA

GitOps / Kubernetes:
- Helm
- Argo CD
- Kyverno

Runtime:
- Falco
- Falcosidekick

Only use badges that are accurate.

======================================================================
TABLE OF CONTENTS
======================================================================

Add a clean table of contents containing sections such as:

- Why This Project Exists
- Architecture
- Security Model
- Pull Request Security
- Trusted Build Pipeline
- Artifact Trust
- GitOps Deployment
- Admission Control
- Runtime Security
- Attack / Failure Scenarios
- Live Validation Evidence
- Repository Structure
- Infrastructure
- CI/CD Workflows
- Security Policies
- Deployment Flow
- Local Validation
- Threat Model / Security Boundaries
- Cost / Cleanup
- Interview Talking Points
- Limitations / Future Improvements

Adjust ordering if another structure is more readable.

======================================================================
MERMAID REQUIREMENTS
======================================================================

IMPORTANT:

Use TREE / BRANCHING diagrams.

DO NOT make the main diagrams simple left-to-right linear boxes.

Prefer:

flowchart TD

with branching subgraphs.

Use meaningful grouping.

Create at least 3 strong Mermaid diagrams.

----------------------------------------------------------------------
MERMAID 1 — END-TO-END SECURITY ARCHITECTURE
----------------------------------------------------------------------

Use `flowchart TD`.

It should branch roughly like:

Developer
 |
 PR
 +-- Semgrep
 +-- Trivy
 +-- Policy Tests
 +-- PR Image Scan
 |
 Main
 |
 GitHub Actions
 +-- OIDC/WIF
 +-- Build + Push
 +-- Scan
 +-- Sign
 +-- SBOM
 +-- Provenance
 |
 Verify Trust
 |
 GitOps
 |
 Argo CD
 |
 Kyverno
 +-- signed + valid -> Admit
 +-- unsigned -> Block
 +-- wrong identity -> Block
 +-- wrong provenance -> Block
 +-- unsigned initContainer -> Block
 |
 GKE
 |
 Falco
 +-- Shell execution
 +-- Runtime event
 +-- Falcosidekick

Use subgraphs such as:

PR Security
Trusted CI
Artifact Trust
GitOps
Admission Security
Runtime Security

Avoid giant text inside nodes.

----------------------------------------------------------------------
MERMAID 2 — TRUST / IDENTITY CHAIN
----------------------------------------------------------------------

Create a tree diagram explaining:

GitHub repository
  |
  +-- main workflow identity
  |      |
  |      +-- GitHub OIDC token
  |             |
  |             +-- GCP Workload Identity Federation
  |
  +-- Cosign keyless certificate identity
  |
  +-- SBOM attestation
  |
  +-- SLSA provenance
          |
          +-- builder
          +-- source repository
          +-- workflow entrypoint
          +-- source commit

Kyverno should validate the expected identity/attestations before allowing the image.

Explain that no long-lived CI service-account JSON key is required in the intended CI path.

----------------------------------------------------------------------
MERMAID 3 — KUBERNETES SECURITY TREE
----------------------------------------------------------------------

Tree structure:

GKE Cluster
 |
 +-- Argo CD
 |      +-- desired state
 |      +-- Helm
 |
 +-- Kyverno
 |      +-- signature verification
 |      +-- SBOM verification
 |      +-- provenance verification
 |      +-- container verification
 |      +-- initContainer verification
 |
 +-- Application
 |      +-- digest-pinned image
 |      +-- replicas
 |
 +-- Falco
        +-- custom rule
        +-- syscall/runtime detection
        +-- Falcosidekick

----------------------------------------------------------------------
OPTIONAL MERMAID 4 — SECURITY FAILURE PATHS
----------------------------------------------------------------------

A branching decision tree is strongly encouraged.

Example:

Container reaches admission
 |
 Is image protected?
 +-- no -> normal policy handling
 |
 +-- yes
      |
      Signature valid?
      +-- no -> DENY
      |
      +-- yes
           |
           SBOM valid?
           +-- no -> DENY
           |
           +-- yes
                |
                Provenance valid?
                +-- no -> DENY
                |
                +-- yes
                     |
                     containers/initContainers trusted?
                     +-- no -> DENY
                     +-- yes -> ADMIT

After admit:
Falco runtime monitoring

This diagram should communicate defense in depth.

======================================================================
SCREENSHOT / LIVE EVIDENCE REQUIREMENTS
======================================================================

The screenshots are real live validation evidence.

Use them throughout the README, not as a random image dump at the end.

Expected screenshot files include:

docs/my-validation/01-pr-security-gates.png
docs/my-validation/02-main-build-pipeline.png
docs/my-validation/03-gar-image-digest.png
docs/my-validation/03b-live-deployment-digest.png
docs/my-validation/04-cosign-verification.png
docs/my-validation/05-sbom-provenance.png
docs/my-validation/06-gke-workloads.png
docs/my-validation/07-argocd-healthy.png
docs/my-validation/07-argocd-healthy-details.png
docs/my-validation/08-trusted-admit.png
docs/my-validation/09-unsigned-blocked.png
docs/my-validation/10-invalid-trust-blocked.png
docs/my-validation/11-init-bypass-blocked.png
docs/my-validation/12-falco-runtime.png

Check actual filenames first.

Do not reference files that do not exist.

======================================================================
HOW TO USE THE SCREENSHOTS
======================================================================

Do NOT simply put all screenshots under:

“Screenshots”

Instead integrate them into the technical story.

Suggested placement:

----------------------------------------------------------------------
PR SECURITY
----------------------------------------------------------------------

Use:

01-pr-security-gates.png

Explain what the image proves:

- relevant PR checks execute
- Semgrep
- Trivy
- policy unit tests
- PR image scan
- PR pipeline does not require privileged cloud mutation
- production signing/deployment jobs are intentionally separated from PR execution

Do not overstate this as a total GitHub security guarantee.

----------------------------------------------------------------------
TRUSTED MAIN PIPELINE
----------------------------------------------------------------------

Use:

02-main-build-pipeline.png

Explain:

Build and Push
      |
Sign, SBOM, Provenance
      |
Verify Signature and Attestations

Mention the actual successful workflow graph.

Explain that trusted operations occur from the main/manual deployment path,
rather than from an untrusted pull request.

----------------------------------------------------------------------
ARTIFACT REGISTRY
----------------------------------------------------------------------

Use:

03-gar-image-digest.png

Explain:

- final container is stored in Artifact Registry
- immutable digest is central to subsequent verification
- tag is convenient metadata; digest is deployment identity

Then use:

03b-live-deployment-digest.png

Explain that Kubernetes runs the same digest.

Do not unnecessarily expose project-specific identifiers in surrounding prose.

----------------------------------------------------------------------
COSIGN
----------------------------------------------------------------------

Use:

04-cosign-verification.png

Explain that this screenshot proves:

- `cosign verify` was actually executed
- expected GitHub Actions workflow identity
- GitHub OIDC issuer
- transparency-log/Rekor verification
- code-signing certificate validation
- exact image digest

Explain keyless signing clearly.

Do not imply a private signing key is stored in GitHub.

----------------------------------------------------------------------
SBOM + PROVENANCE
----------------------------------------------------------------------

Use:

05-sbom-provenance.png

Explain the evidence:

- SPDX document
- package enumeration/count if visible
- SLSA provenance
- GitHub Actions runner builder
- workflow entrypoint
- source repository
- source commit
- subject digest

Explain the difference:

SBOM answers:
“What is inside the artifact?”

Provenance answers:
“Where and how was this artifact built?”

Keep this technically accurate.

----------------------------------------------------------------------
CLUSTER HEALTH
----------------------------------------------------------------------

Use:

06-gke-workloads.png

Explain that the live cluster shows:

- node Ready
- app replicas running
- Argo CD running
- Kyverno running
- Falco running
- Falcosidekick running

This is supporting infrastructure evidence.

----------------------------------------------------------------------
ARGO CD
----------------------------------------------------------------------

Use both if useful:

07-argocd-healthy.png
07-argocd-healthy-details.png

First screenshot:
- Healthy
- Synced
- resource tree

Second screenshot:
- canonical Git repository
- main revision
- Helm path
- deployed immutable digest

Explain desired-state reconciliation.

Do not claim Argo CD itself verifies cryptographic signatures unless repository code truly does so.
Kyverno is the admission trust enforcement layer.

----------------------------------------------------------------------
TRUSTED ADMISSION
----------------------------------------------------------------------

Use:

08-trusted-admit.png

Explain:

- Helm rendered manifest
- server-side dry-run
- API server/Kyverno admitted it
- live Deployment has expected replicas
- exact trusted digest runs

Make clear:

success here means the trusted image passed the configured admission policy.

----------------------------------------------------------------------
UNSIGNED IMAGE BLOCK
----------------------------------------------------------------------

Use:

09-unsigned-blocked.png

Explain:

- server-side admission request
- protected unsigned image
- Kyverno denial
- `no signatures found`
- missing matching attestations

This is an important negative test.

----------------------------------------------------------------------
INVALID TRUST BLOCK
----------------------------------------------------------------------

Use:

10-invalid-trust-blocked.png

Explain:

- temporary policy intentionally expects incorrect signer/provenance
- known signed image is tested
- workload is denied due to trust mismatch
- test policy is removed immediately afterward

This proves the policy validates expected identity/provenance,
not merely the existence of some signature.

----------------------------------------------------------------------
BYPASS RESISTANCE
----------------------------------------------------------------------

Use:

11-init-bypass-blocked.png

Explain both tests:

1. trusted + untrusted mixed container scenario
2. unsigned initContainer scenario

Explain why this matters:

Verifying only the primary application container could leave a bypass path.
The policy tests ensure protected container references are verified across the relevant Pod image fields.

Be precise based on actual Kyverno policy implementation.

----------------------------------------------------------------------
RUNTIME SECURITY
----------------------------------------------------------------------

Use:

12-falco-runtime.png

Explain:

- controlled `kubectl exec`
- `/bin/sh -c id`
- workload shell execution
- Falco custom rule
- Critical event
- matching pod
- matching namespace
- matching command

Explain:

Kyverno protects admission time.
Falco protects/detects runtime behavior.

This is a powerful security-layer distinction.

======================================================================
EVIDENCE MATRIX
======================================================================

Add a compact evidence table such as:

| Control | Tool | Positive/Negative Test | Evidence |
|---|---|---|---|
| PR SAST | Semgrep | Positive | screenshot |
| Dependency/image scanning | Trivy | Positive | screenshot |
| Keyless signing | Cosign | Positive | screenshot |
| SBOM | SPDX | Positive | screenshot |
| Provenance | SLSA | Positive | screenshot |
| GitOps | Argo CD | Positive | screenshot |
| Trusted admission | Kyverno | Positive | screenshot |
| Unsigned image | Kyverno | Negative | screenshot |
| Wrong identity/provenance | Kyverno | Negative | screenshot |
| Init-container bypass | Kyverno | Negative | screenshot |
| Runtime shell | Falco | Detection | screenshot |

Link each evidence cell to the corresponding image.

======================================================================
SECURITY MODEL SECTION
======================================================================

Create a detailed section explaining the project as multiple security layers.

For example:

Layer 1 — Source/PR Security
- Semgrep
- Trivy
- policy tests
- PR image scan

Layer 2 — Cloud Authentication
- GitHub OIDC
- GCP Workload Identity Federation
- no long-lived CI service-account key in normal workflow

Layer 3 — Artifact Integrity
- immutable image digest
- Cosign keyless signing
- SBOM
- SLSA provenance

Layer 4 — Deployment Integrity
- Git desired state
- Argo CD
- digest-pinned deployment

Layer 5 — Admission Security
- Kyverno
- signature verification
- attestation checks
- identity/provenance conditions
- init/container verification

Layer 6 — Runtime Detection
- Falco
- custom rules
- Falcosidekick

For each layer explain:

WHAT it protects
WHY it exists
WHAT attack/failure it addresses

======================================================================
PULL REQUEST TRUST BOUNDARY
======================================================================

This deserves its own section.

Clearly explain:

Untrusted PR:
- should perform relevant non-privileged security checks
- should NOT receive production GCP WIF privileges
- should NOT push trusted production artifacts
- should NOT create production signatures
- should NOT create production attestations
- should NOT deploy to GKE

Trusted main path:
- can acquire short-lived identity
- build/push/sign/attest/verify
- update trusted deployment state as actually implemented

Use actual workflow event configuration to ensure every statement is accurate.

If the workflow supports `workflow_dispatch`, document that correctly.

======================================================================
COSIGN / SIGSTORE SECTION
======================================================================

Explain keyless signing accurately.

Discuss:

GitHub Actions workflow
  |
OIDC identity
  |
Fulcio / keyless certificate model if applicable to actual Cosign flow
  |
Cosign signature
  |
OCI metadata repository
  |
Rekor transparency log
  |
Verification

Do not invent detailed Sigstore behavior unsupported by actual tools.

Explain the expected signer identity from the current canonical repository,
but avoid unnecessarily hardcoding sensitive details.

The repository name itself is public and can be shown.

======================================================================
SBOM / SLSA SECTION
======================================================================

Explain:

SPDX SBOM:
- package inventory
- artifact association
- software composition evidence

SLSA provenance:
- builder
- workflow entrypoint
- repository/source
- source revision
- subject digest

Explain why these are attestations and how Kyverno uses them if that is what the actual policy does.

======================================================================
KYVERNO SECTION
======================================================================

This should be detailed.

Inspect the actual ClusterPolicy.

Explain the actual rules.

Expected policy concept:

block-unsigned-images

Potential rules include:

- verify image signature
- verify SBOM attestation
- verify provenance attestation

Verify exact names from YAML.

Explain:

- protected image scope
- keyless identity requirements
- issuer
- provenance conditions
- digest verification
- containers/initContainers handling
- enforcement mode

If special Kyverno configuration such as increased context size is still present,
explain briefly why it exists, but only if confirmed in the repository.

Do not discuss Gatekeeper as an active admission engine if it is not deployed.

======================================================================
ATTACK / NEGATIVE TEST SECTION
======================================================================

Create a strong section:

## Security Tests: What Happens When Trust Breaks?

Use a table like:

| Scenario | Expected Result | Actual Result |
|---|---|---|
| Trusted signed image | Admit | PASS |
| Unsigned image | Deny | PASS |
| Wrong signer identity | Deny | PASS |
| Wrong provenance source | Deny | PASS |
| Untrusted mixed container | Deny | PASS |
| Unsigned initContainer | Deny | PASS |
| Runtime shell execution | Falco Critical detection | PASS |

Only mark PASS where real evidence exists.

Link to screenshots.

This should become one of the strongest sections of the README.

======================================================================
RUNTIME SECURITY SECTION
======================================================================

Explain the conceptual difference:

BUILD TIME:
Semgrep / Trivy

ARTIFACT TIME:
Cosign / SBOM / provenance

ADMISSION TIME:
Kyverno

RUNTIME:
Falco

Use a table to make this extremely clear.

Explain the controlled Falco validation event.

Mention Falcosidekick is deployed if verified.

If external Discord alerting is NOT currently configured:

explicitly state something like:

“Falco runtime detection and Falcosidekick are deployed and validated. External Discord notification is intentionally not enabled in the public reference deployment because no real webhook is committed to the repository.”

Do not claim an external alert was received unless evidence exists.

======================================================================
INFRASTRUCTURE SECTION
======================================================================

Explain Terraform at an architectural level.

Inspect actual Terraform before writing.

Likely areas:

- VPC
- GKE
- Artifact Registry
- IAM
- Workload Identity Federation
- service accounts
- networking
- runtime/security components

Do not list modules that are preserved but unused as active deployment components.

Add a compact resource tree if useful:

Infrastructure
├── Network
├── GKE
├── Artifact Registry
├── IAM
├── Workload Identity Federation
├── Argo CD
├── Kyverno
└── Falco

Use actual repository structure.

======================================================================
REPOSITORY STRUCTURE
======================================================================

Include a clean repository tree such as:

.
├── .github/
│   └── workflows/
├── app/
├── argocd/
├── docs/
├── infrastructure/
├── k8s/
│   └── helm/
├── policy/
├── terraform/
├── Dockerfile
└── README.md

But generate the tree from the REAL repository.

For each major directory add a short purpose description.

Do not include hundreds of files.

======================================================================
CI WORKFLOW SECTION
======================================================================

Inspect actual active root workflows.

Create a table:

| Workflow | Trigger | Responsibility |
|---|---|---|

Include only active workflows.

Potential examples:

- pr-check.yml
- deploy.yml
- build-push.yml
- sign-attest.yml
- verify.yml
- security-scan.yml
- infrastructure-terraform.yml

Verify actual filenames/triggers.

Explain reusable workflow relationships.

Do not describe nested historical infrastructure workflows as active GitHub Actions
unless they actually execute from `.github/workflows/`.

======================================================================
DEPLOYMENT / QUICK START
======================================================================

Create a practical section for someone who wants to understand or reproduce the project.

Do not expose real secrets.

Use placeholders.

Separate:

Prerequisites
- gcloud
- Terraform
- Docker
- kubectl
- Helm
- Cosign
- GitHub CLI if required

Authentication
- explain required GCP/GitHub setup conceptually
- use placeholders

Infrastructure deployment
- use actual repo commands where safe

Cluster credentials
- use placeholders

Argo CD
- explain how application is configured

Local validation
- include safe commands

Do not put credentials into README.

Do not make destructive commands prominent without warnings.

======================================================================
LOCAL SECURITY VALIDATION
======================================================================

Add a compact validation section.

Use safe commands based on the actual repo, potentially:

terraform fmt -check -recursive infrastructure terraform

terraform -chdir=infrastructure/environments/prod validate

helm lint k8s/helm/supply-chain-demo

helm template ...

kubectl apply --dry-run=client ...

policy tests

identity consistency tests

Do not include commands that depend on personal secrets.

======================================================================
THREAT MODEL / WHAT THIS PROJECT DEFENDS AGAINST
======================================================================

Add a concise but valuable threat table.

Examples, only where supported:

| Threat | Mitigation |
|---|---|
| Vulnerable source/dependencies | Semgrep + Trivy |
| Long-lived CI cloud credentials | OIDC + WIF |
| Image tag mutation | digest pinning |
| Unsigned artifact | Cosign + Kyverno |
| Artifact from untrusted workflow | certificate identity validation |
| Missing SBOM | attestation enforcement |
| Incorrect build source/provenance | SLSA condition checks |
| Init-container bypass | image verification rules |
| Runtime interactive shell | Falco detection |

Do not claim protection beyond implementation.

For example, do not imply Falco prevents shell execution if it only detects it.

Use language:

detects
blocks
verifies
reduces

accurately.

======================================================================
DESIGN DECISIONS
======================================================================

Add a section explaining important technical decisions.

Examples:

### Why digest pinning instead of `latest`?
Explain immutability.

### Why GitHub OIDC + WIF instead of JSON service-account keys?
Explain short-lived identity and secret reduction.

### Why keyless Cosign?
Explain identity-bound signing.

### Why SBOM + provenance?
SBOM = contents.
Provenance = origin/build process.

### Why Kyverno?
Admission-time enforcement.

### Why Argo CD?
Git remains desired-state source.

### Why Falco after Kyverno?
Admission controls cannot detect all post-admission behavior.

### Why separate PR and main trust boundaries?
Untrusted PR code should not receive production signing/deployment privileges.

These explanations should be concise but technically substantive.

======================================================================
LIMITATIONS / FUTURE IMPROVEMENTS
======================================================================

Include a transparent section.

Potential current limitations, only if accurate:

- demo/reference workload, not a business application
- one active environment
- external Discord alerting intentionally disabled unless configured
- branch protection/rulesets may depend on GitHub account capabilities
- no production ingress/custom domain
- no full SIEM
- no multi-cluster deployment
- no service mesh

Do not make these sound like failures.

Call it something like:

## Current Scope & Future Improvements

Potential future improvements:

- GitHub ruleset enforcement
- SIEM integration
- stronger alert routing
- additional policy test coverage
- multi-environment promotion
- workload-specific security profiles

Do not add huge unrelated tools just for buzzwords.

======================================================================
INTERVIEW / RESUME VALUE
======================================================================

Add a small section near the end:

## What This Project Demonstrates

Focus on skills:

- Terraform/GCP infrastructure
- Kubernetes/GKE
- GitHub Actions
- CI trust-boundary design
- OIDC/WIF
- container scanning
- Cosign/Sigstore
- SBOM/provenance
- GitOps/Argo CD
- Kyverno
- runtime Falco
- debugging real admission/security failures

Do not literally write “hire me”.

Keep it professional.

======================================================================
SCREENSHOT PRESENTATION STYLE
======================================================================

Use standard Markdown images.

Example:

```markdown
### Pull Request Security Gates

![Pull Request Security Gates](docs/my-validation/01-pr-security-gates.png)

The PR path executes only non-privileged validation...
