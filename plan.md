# GCP Software Supply Chain & Runtime Security

# Full Codex Implementation Mission — MONOREPO VERSION

You are working on Project 1 of my DevOps portfolio.

The project has ALREADY been converted from two upstream Git repositories into ONE history-preserving monorepo.

DO NOT repeat the repository merge.

DO NOT clone the two upstream repositories again.

DO NOT restructure history.

---

# 0. CURRENT REPOSITORY STATE — READ THIS FIRST

The current working repository is the combined monorepo:

```text
gcp-supply-chain-security/
```

Its current logical structure is approximately:

```text
gcp-supply-chain-security/
│
├── .github/
├── app/
├── argocd/
├── docs/
├── k8s/
├── policy/
├── terraform/
├── Dockerfile
├── README.md
│
└── infrastructure/
    ├── .github/
    ├── environments/
    ├── vpc/
    ├── gke/
    ├── kubernetes-addons/
    ├── falco/
    ├── falco-alerting/
    ├── README.md
    └── <all other original infrastructure files>
```

The root of the monorepo contains the former:

```text
musaumakau/supply-chain-security
```

repository.

The directory:

```text
infrastructure/
```

contains the complete former:

```text
musaumakau/gcp-infrastructure-modules
```

repository tree.

They are now ONE Git repository and ONE portfolio project.

---

# 1. CRITICAL HISTORY STATE — NEVER MODIFY THIS

The monorepo merge has already been completed and validated.

Known preserved historical commits:

```text
Original application HEAD:
cf131149fd7f3c052c04875b21979e75b44c1d93

Original infrastructure HEAD:
d15ce7522d4c175f6dcba8b1082dd0a781c4160d

History-preserving merge commit:
76c26bd21fb8ec6053b315cdb51580dfa3b62336

Post-merge documentation HEAD at completion:
3d29f6f7b03db8d2671b307d722454fbb1e0405d
```

The merge commit has TWO parents:

```text
parent 1:
cf131149fd7f3c052c04875b21979e75b44c1d93

parent 2:
d15ce7522d4c175f6dcba8b1082dd0a781c4160d
```

Both upstream histories are preserved.

The repository contains:

```text
docs/repository-merge.md
```

documenting the operation.

Original historical source branch references were retained under names similar to:

```text
app-source/*
infra-source/*
```

Source push URLs were disabled during the merge.

---

# 2. HISTORY SAFETY RULES

From this point onward:

DO NOT:

```text
git rebase upstream history
git filter-repo
git filter-branch
git replace
rewrite authors
rewrite dates
squash the upstream histories
recreate the merge
remove the merge commit
force-push rewritten history
delete historical source refs without reason
```

DO NOT amend:

```text
76c26bd21fb8ec6053b315cdb51580dfa3b62336
```

or:

```text
3d29f6f7b03db8d2671b307d722454fbb1e0405d
```

All project implementation work should happen as NEW commits after the existing monorepo history.

Before major implementation begins verify:

```bash
git merge-base --is-ancestor \
  cf131149fd7f3c052c04875b21979e75b44c1d93 \
  HEAD

git merge-base --is-ancestor \
  d15ce7522d4c175f6dcba8b1082dd0a781c4160d \
  HEAD
```

Both commands must succeed.

Also verify:

```bash
git show \
  --no-patch \
  --pretty=raw \
  76c26bd21fb8ec6053b315cdb51580dfa3b62336
```

and confirm that it still has two parents.

Record this validation in the repository audit.

---

# 3. UPSTREAM ORIGIN / ATTRIBUTION

This monorepo combines work originally sourced from:

## Application/security component

```text
https://github.com/musaumakau/supply-chain-security
```

## Infrastructure component

```text
https://github.com/musaumakau/gcp-infrastructure-modules
```

Do not pretend the upstream code was originally authored by me.

Preserve:

* authorship
* commit history
* license files
* notices
* historical documentation
* `docs/repository-merge.md`

The final README must credit both upstream repositories.

---

# 4. FINAL PROJECT POSITIONING

The final project is:

# GCP Software Supply Chain & Runtime Security

This is a:

```text
DevSecOps
+
GCP
+
Kubernetes Security
```

project.

It is NOT:

```text
Platform Engineering
Internal Developer Platform
Backstage Platform
Self-Service Platform
```

---

# 5. PRIMARY OBJECTIVE

Take the current combined monorepo from its post-merge state to a fully:

* adapted
* deployed
* tested
* security-validated
* documented
* screenshot-ready
* resume-ready
* interview-ready

project running in MY GCP environment.

The final architecture should approximately become:

```text
Developer
   │
   ▼
Pull Request
   │
   ├── Semgrep SAST
   └── Trivy filesystem scan
            │
            ▼
         Merge main
            │
            ▼
      GitHub Actions
            │
         GitHub OIDC
            │
            ▼
GCP Workload Identity Federation
            │
            ▼
Google Artifact Registry
            │
            ├── Trivy image scan
            ├── Cosign keyless signature
            ├── SPDX SBOM
            └── SLSA provenance
                     │
                     ▼
                  Verification
                     │
                     ▼
                   Git
                     │
                     ▼
                  Argo CD
                     │
                     ▼
                   Kyverno
                     │
               Admission Control
               ┌─────┴─────┐
               │           │
            trusted     untrusted
               │           │
             ADMIT        BLOCK
               │
               ▼
              GKE
               │
              Falco
               │
         Falcosidekick
               │
         Runtime Alerting
```

If the retained Falco alerting architecture is still appropriate:

```text
Falco
 ↓
Falcosidekick
 ↓
Pub/Sub
 ↓
Cloud Function
 ↓
Discord
```

may remain.

Authentication for that path MUST be audited.

---

# 6. MONOREPO RESPONSIBILITY MODEL

There are no longer two repositories.

There are two COMPONENT AREAS inside one repository.

## Root application/security area

Contains concepts such as:

```text
app/
Dockerfile
.github/
argocd/
k8s/
policy/
terraform/
```

Responsible for:

```text
application
CI
Semgrep
Trivy
GAR pipeline
Cosign
SBOM
SLSA
Kyverno
Argo CD
Helm workload
negative tests
GitHub rulesets
```

---

## `infrastructure/` area

Contains the former infrastructure repository.

Responsible for:

```text
Terraform GCP infrastructure
VPC
subnets
Cloud NAT
GKE
node pools
Kubernetes add-ons
Falco
Falcosidekick
Pub/Sub
Cloud Function alerting
```

From now on describe them as:

```text
application/security layer
```

and:

```text
infrastructure/runtime-security layer
```

NOT "Repo 1" and "Repo 2".

---

# 7. FINAL PROJECT MUST PROVE

The finished project must demonstrate with actual validation:

1. Terraform provisions the required GCP infrastructure.
2. GKE becomes healthy and usable.
3. GitHub Actions authenticates to GCP with Workload Identity Federation.
4. CI does NOT require a long-lived GCP service-account JSON key.
5. Pull requests are scanned with Semgrep.
6. Pull requests are scanned with Trivy.
7. Main-branch builds create Docker images.
8. Images are pushed to GAR.
9. Images use immutable SHA/digest identity instead of `latest`.
10. The produced container is scanned with Trivy.
11. Cosign performs keyless signing.
12. An SPDX SBOM is generated.
13. SLSA provenance is generated.
14. Signature verification succeeds.
15. SBOM attestation verification succeeds.
16. Provenance verification succeeds.
17. Argo CD deploys the trusted workload.
18. Kyverno verifies images during admission.
19. Trusted artifact is admitted.
20. Unsigned artifact is denied.
21. Invalid/untrusted provenance or identity is denied.
22. An untrusted initContainer cannot bypass policy.
23. Falco detects at least one controlled runtime event.
24. Runtime alerting works end-to-end.
25. README claims match real validation.
26. Screenshots come from MY deployment.
27. Both upstream projects are clearly credited.
28. Resume bullets contain only validated claims.

---

# 8. STRICT SCOPE CONTROL

DO NOT expand the project beyond the supply-chain-security story.

## KEEP

* GCP
* Terraform
* GKE
* GitHub Actions
* GitHub OIDC
* GCP Workload Identity Federation
* GAR
* Docker
* Semgrep
* Trivy
* Cosign
* Sigstore concepts
* Syft
* SPDX SBOM
* SLSA provenance
* Kyverno
* Argo CD
* Helm
* Falco
* Falcosidekick/runtime alerting

---

# 9. OUT OF FINAL DEPLOYMENT SCOPE

Do NOT deploy unless absolutely required for compatibility:

* Gatekeeper
* Ratify
* VEX enforcement
* Backstage
* Crossplane
* Istio
* Linkerd
* service mesh
* Argo Rollouts
* Prometheus
* Grafana
* Loki
* Tempo
* OpenTelemetry
* Vault
* cert-manager
* ExternalDNS
* custom domains
* production ingress
* multi-environment architecture
* staging
* application feature development
* additional policy engines

Existing code/config for these components may remain in the repository.

DO NOT delete upstream code merely because it is not part of my deployment scope.

The final admission engine I actually deploy and validate is:

# Kyverno

Do not deploy Gatekeeper + Ratify.

---

# 10. IMPORTANT — PRESERVE UNUSED UPSTREAM CODE

Because this monorepo intentionally preserves both upstream repositories:

DO NOT start deleting:

```text
Gatekeeper files
Ratify files
VEX files
unused examples
old docs
infrastructure examples
nested workflows
tests
configs
```

simply because they are outside my deployment scope.

Prefer:

```text
preserve code
+
document "not deployed in my scope"
```

over deleting history-derived material.

Only delete something if:

1. it creates an actual runtime conflict, AND
2. the reason is documented, AND
3. there is no safer disable/configuration approach.

---

# 11. AUDIT FIRST — IMPLEMENT SECOND

Before changing implementation:

perform a COMPLETE monorepo audit.

Do not trust README claims blindly.

Trust:

```text
Terraform
GitHub Actions
Helm
Kubernetes YAML
policy code
application code
```

over documentation.

Document every discrepancy.

Do NOT begin cloud implementation until:

```text
docs/codex/00-REPO-AUDIT.md
```

and:

```text
docs/codex/01-IMPLEMENTATION-PLAN.md
```

exist and are complete.

Then continue automatically.

---

# 12. MONOREPO WORKFLOW SPECIAL CASE

The former infrastructure repository's workflows now live under:

```text
infrastructure/.github/workflows/
```

GitHub does NOT execute workflows from this nested location.

This is EXPECTED after the history-preserving merge.

DO NOT delete or move those files during initial audit.

They are preserved upstream artifacts.

During implementation determine whether any infrastructure workflow is required for the final project.

If a nested infrastructure workflow is useful:

prefer creating an adapted active copy under:

```text
.github/workflows/
```

with:

* correct monorepo paths
* `working-directory: infrastructure/...`
* appropriate `paths:` filters
* correct secrets/variables
* no duplicate unintended triggers

Keep the original nested workflow for provenance unless there is a strong reason not to.

Document this decision.

Do NOT blindly copy every nested infrastructure workflow into root.

---

# 13. MONOREPO PATH RULE

Whenever an old infrastructure instruction references:

```text
gcp-infrastructure-modules/<path>
```

the new monorepo path is generally:

```text
infrastructure/<path>
```

Examples:

```text
OLD:
gcp-infrastructure-modules/environments/prod

NEW:
infrastructure/environments/prod
```

```text
OLD:
gcp-infrastructure-modules/gke

NEW:
infrastructure/gke
```

```text
OLD:
gcp-infrastructure-modules/falco

NEW:
infrastructure/falco
```

Do not rename these directories merely for aesthetics.

Preserve their internal relative structure unless a real integration problem requires a change.

---

# 14. DOCUMENTATION CONTROL DIRECTORY

All Codex tracking lives at the MONOREPO root:

```text
docs/codex/
```

Create:

```text
docs/codex/
├── 00-REPO-AUDIT.md
├── 01-IMPLEMENTATION-PLAN.md
├── 02-PROJECT-STATUS.md
├── 03-VALIDATION.md
├── 04-DECISIONS.md
├── 05-HANDOFF.md
├── 06-RESOURCE-INVENTORY.md
├── 07-COST-AND-CLEANUP.md
└── 08-SCREENSHOT-CHECKLIST.md
```

Do NOT create a second Codex documentation tree under:

```text
infrastructure/
```

There is one project and one status source.

---

# 15. `00-REPO-AUDIT.md`

Audit the COMPLETE monorepo.

Start with Git history integrity.

Record:

```text
current HEAD
branch
remotes
merge commit
merge parents
application original HEAD ancestry
infrastructure original HEAD ancestry
source refs
working tree status
```

Verify `docs/repository-merge.md`.

Then audit:

## Root application/security area

* root directory structure
* application
* Dockerfile
* root GitHub Actions
* reusable workflows
* composite actions
* Semgrep configuration
* Trivy configuration
* GAR configuration
* GCP authentication
* Cosign configuration
* Syft
* SBOM generation
* SLSA generation
* verification flow
* Kyverno
* Gatekeeper/Ratify retained code
* Argo CD Applications
* Helm chart
* negative tests
* policy tests
* GitHub ruleset Terraform
* docs/evidence/runbooks
* hardcoded upstream values
* repository identity assumptions
* GCP project assumptions

## `infrastructure/`

Inspect:

```text
infrastructure/environments/prod/
infrastructure/vpc/
infrastructure/gke/
infrastructure/kubernetes-addons/
infrastructure/falco/
infrastructure/falco-alerting/
infrastructure/.github/workflows/
infrastructure/.infracost/
infrastructure/README.md
```

Also inspect any additional modules discovered there.

For every infrastructure module record:

```text
inputs
outputs
resources
providers
authentication
dependencies
cost implications
required for our deployment?
```

---

# 16. AUDIT MONOREPO INTEGRATION ISSUES

Specifically identify problems caused by combining the repos.

Check for:

```text
duplicate file concepts
nested .github workflows
duplicate .gitignore behavior
duplicate Terraform configurations
duplicate docs
relative path assumptions
repoURL assumptions
GitHub repository-name assumptions
source-repository provenance assumptions
Renovate/config paths
CI path filters
module source paths
working-directory assumptions
scripts assuming old repo root
README links pointing to second repository
```

Do NOT automatically "fix" them during audit.

Document first.

---

# 17. KNOWN DOCUMENTATION MISMATCH TO VERIFY

The former infrastructure top-level documentation historically claimed:

```text
kubernetes-addons
```

deployed:

```text
Kyverno
Gatekeeper
cert-manager
ExternalDNS
```

but executable Terraform has previously shown only:

```text
metrics-server
ExternalDNS
```

Verify CURRENT:

```text
infrastructure/kubernetes-addons/
```

Do not trust historical assumptions.

Record:

```text
README claim
actual Terraform
our deployment decision
```

If Kyverno is not provisioned by Terraform:

install it separately with Helm.

Do not rebuild the entire Terraform module just to add Kyverno.

---

# 18. FALCOSIDEKICK AUTHENTICATION AUDIT

Inspect current:

```text
infrastructure/falco/
infrastructure/falco-alerting/
```

and pinned chart versions.

Determine whether Falcosidekick can currently use:

```text
GKE Workload Identity
```

for Pub/Sub.

Check:

* Kubernetes ServiceAccount support
* workload identity annotations
* current Helm values schema
* GCP Pub/Sub authentication behavior

Preferred:

```text
Falcosidekick
 ↓
GKE Workload Identity
 ↓
Pub/Sub
```

If genuinely unsupported:

use the upstream minimally scoped static-key mechanism ONLY for Falcosidekick.

Then:

* dedicated SA
* minimum Pub/Sub permissions
* no reuse of CI identity
* no Git commit of JSON key
* document rotation/revocation
* delete key after project testing

Never claim the entire architecture is keyless if this exception remains.

Instead say:

```text
GitHub Actions → GCP:
keyless WIF

Falcosidekick → Pub/Sub:
documented scoped exception
```

if applicable.

---

# 19. `01-IMPLEMENTATION-PLAN.md`

After audit, write the COMPLETE plan.

For every phase:

```text
Objective

Current State

Required Changes

Files Affected

Commands

Cloud Resources Affected

Expected Result

Validation

Possible Failure Modes

Rollback / Recovery

Human Action Required?

Cost Impact
```

Include diagrams for:

1. monorepo layout
2. final architecture
3. artifact trust chain
4. runtime alerting chain
5. deployment sequence

There is no longer a "repo relationship diagram".

Use a:

```text
monorepo component boundary diagram
```

instead.

---

# 20. `02-PROJECT-STATUS.md`

Maintain:

```text
Current Phase
Current Status
Completed
In Progress
Blocked
Next Action

Monorepo Status
Application/Security Layer Status
Infrastructure Layer Status

GitHub Repository Status
GCP Project

Terraform Status
GKE Status
GAR Status
WIF Status
GitHub Actions Status

Kyverno Status
Argo CD Status

Falco Status
Runtime Alert Status

Known Issues
Last Successful Command
Next Command
Last Updated
```

Do NOT use:

```text
Application Repo Status
Infrastructure Repo Status
```

because they are no longer separate repos.

---

# 21. `03-VALIDATION.md`

Maintain:

| ID | Test | Expected | Actual | Status | Evidence |
| -- | ---- | -------- | ------ | ------ | -------- |

Include:

```text
V00 Monorepo history integrity
V01 Terraform fmt
V02 Terraform validate
V03 Terraform plan
V04 Terraform apply
V05 GKE nodes Ready
V06 CI WIF authentication
V07 PR Semgrep
V08 PR Trivy
V09 Docker build
V10 GAR push
V11 Trivy image scan
V12 Cosign signature
V13 SBOM generation
V14 SLSA provenance
V15 signature verification
V16 SBOM verification
V17 provenance verification
V18 Argo CD sync
V19 trusted image admitted
V20 unsigned image blocked
V21 invalid identity/provenance blocked
V22 mixed/init-container bypass blocked
V23 application reachable
V24 Falco runtime event detected
V25 external alert delivered
V26 final Terraform plan/no unexplained drift
V27 original app history still reachable
V28 original infra history still reachable
```

Never mark PASS without testing.

---

# 22. `04-DECISIONS.md`

ADR topics:

```text
Why the project uses one monorepo

Why infrastructure remains under /infrastructure

Why historical upstream files are preserved

Why nested infrastructure workflows remain preserved

Which infrastructure workflows, if any, were promoted to root .github

Why Kyverno only

Why Gatekeeper/Ratify was excluded from deployment

Why digest-pinned deployment is used

Why GitHub→GCP uses WIF

Why Cosign is keyless

Signature vs SBOM vs provenance

Why admission security != runtime security

Why Falco is retained

Falcosidekick authentication decision

Why Argo CD is used

Why observability stack is excluded

Why custom domain/Ingress is excluded

Why this is DevSecOps and not platform engineering
```

---

# 23. `05-HANDOFF.md`

Must answer:

```text
Where are we?

What works?

What is broken?

What was the last successful action?

What is the exact next action?

What human action is required?

What GCP resources currently exist?

What local credentials/secrets exist?

Are billable resources running?

Is it safe to stop?

What should a fresh Codex session run first?
```

Update before ending every session.

---

# 24. `06-RESOURCE-INVENTORY.md`

Track:

```text
GCP project
GCS state bucket

VPC
subnets
Cloud Router
Cloud NAT

GKE cluster
node pools
node service accounts

GAR repository

GitHub CI service account
WIF pool
WIF provider

Pub/Sub
Falco service account if necessary
Cloud Function
function runtime resources

storage buckets
load balancers
public IPs
```

For each:

```text
Resource
Name
Region
Purpose
Created?
Cost relevance
Managed by Terraform/manual?
Destroy mechanism
```

Never store secret material.

---

# 25. PHASE 0 — VERIFY CURRENT MONOREPO STATE

Start from the CURRENT repository root.

Run:

```bash
pwd
git status
git branch --show-current
git remote -v
git log --graph --decorate --oneline -30
```

Verify:

```text
infrastructure/
docs/repository-merge.md
```

exist.

Verify ancestry:

```bash
git merge-base --is-ancestor \
  cf131149fd7f3c052c04875b21979e75b44c1d93 \
  HEAD

git merge-base --is-ancestor \
  d15ce7522d4c175f6dcba8b1082dd0a781c4160d \
  HEAD
```

Verify merge parents:

```bash
git show \
  --no-patch \
  --pretty=raw \
  76c26bd21fb8ec6053b315cdb51580dfa3b62336
```

If any history validation fails:

STOP.

Do not proceed with implementation until the monorepo state is understood.

---

# 26. DO NOT TOUCH THE ORIGINAL SOURCE CLONES

If the original sibling clones still exist outside this repository:

```text
../supply-chain-security
../gcp-infrastructure-modules
```

treat them as READ-ONLY backups.

Do not make implementation changes there.

Do not commit there.

Do not push there.

Everything now happens inside:

```text
gcp-supply-chain-security/
```

---

# 27. PHASE 1 — GITHUB MONOREPO CREATION / REMOTE CHECK

The combined monorepo may not yet be pushed to my GitHub account.

Inspect:

```bash
git remote -v
gh auth status
```

The desired GitHub repository is:

```text
gcp-supply-chain-security
```

under MY GitHub account.

This must be a NEW standalone repository.

It should NOT use GitHub's Fork mechanism.

---

## Remote safety

Never push to either original upstream repository.

If a source remote exists, keep it clearly reference-only.

Desired conceptual remotes:

```text
origin
→ MY GitHub monorepo

app-source / upstream-app
→ original application history reference

infra-source / upstream-infra
→ original infrastructure history reference
```

Any source/upstream push URL should remain disabled where already configured.

---

## If personal `origin` is missing

If `gh` is authenticated and my GitHub account can be determined safely:

create:

```text
gcp-supply-chain-security
```

as a new public repository and set it as:

```text
origin
```

Do NOT:

```text
fork
force push
overwrite an existing unrelated repository
```

If a repository with that exact name already exists:

inspect it before doing anything.

Never destroy/overwrite it.

---

## Push monorepo

Push:

```text
main
```

normally.

No force push.

Verify the remote repository contains the complete merged history.

Record final GitHub URL.

This URL becomes the canonical repository identity for:

```text
WIF
Cosign certificate identity
SLSA source repository
Kyverno trust
Argo CD repoURL
README
```

---

# 28. PHASE 2 — FULL MONOREPO APPLICATION/SECURITY AUDIT

Inspect root:

```text
.github/
app/
argocd/
docs/
k8s/
policy/
terraform/
Dockerfile
README.md
renovate.json
.trivyignore
```

Read EVERY active root GitHub workflow.

Expected candidates may include:

```text
.github/workflows/pr-check.yml
.github/workflows/deploy.yml
.github/workflows/build-push.yml
.github/workflows/sign-attest.yml
.github/workflows/verify.yml
```

Do not assume exact names.

Determine:

```text
triggers
permissions
job dependencies
working directories
inputs
outputs
identity claims
GAR paths
project IDs
region
GitHub repository identity
workflow identity
tagging strategy
digest handling
SARIF
artifacts
```

Draw exact CI graph.

---

# 29. PHASE 3 — AUDIT NESTED INFRASTRUCTURE WORKFLOWS

Read:

```text
infrastructure/.github/workflows/
```

even though GitHub will not execute them there.

For each determine:

```text
purpose
trigger
Terraform working directory
security checks
Infracost usage
authentication
required secrets
whether it adds value to MY final project
```

Classify each:

```text
PRESERVE ONLY

or

PROMOTE/ADAPT TO ROOT .github/workflows/
```

Do not delete the nested source.

If promoting:

create a root workflow with a clear name, for example:

```text
infrastructure-terraform-ci.yml
```

and use proper monorepo path filters such as:

```yaml
paths:
  - "infrastructure/**"
```

and correct working directory.

Only do this if the existing workflow is useful.

---

# 30. PHASE 4 — AUDIT KYVERNO

Inspect:

```text
policy/kyverno/block-unsigned-images.yaml
```

Document every rule.

Expected concepts:

```text
signature verification
SBOM verification
SLSA provenance verification
```

Inspect:

```text
imageReferences
certificate identity
OIDC issuer
attestors
attestation types
JMESPath
repository URI
workflow entryPoint
namespace exclusions
verifyDigest
failure mode
```

Search all upstream identities.

Do not modify until audit is documented.

---

# 31. PHASE 5 — AUDIT ARGO CD

Inspect:

```text
argocd/supply-chain-demo-app.yaml
argocd/supply-chain-test-negative-app.yaml
```

Determine:

```text
repoURL
targetRevision
path
sync
prune
selfHeal
destination
negative test behavior
```

Eventually both must reference the NEW monorepo URL where appropriate.

---

# 32. PHASE 6 — AUDIT HELM

Inspect:

```text
k8s/helm/supply-chain-demo/
```

Determine:

```text
repository
digest
tag
pullPolicy
securityContext
service
ports
probes
resources
```

Final trusted deployment should be:

```text
digest pinned
```

Do not fabricate a digest.

The digest must be produced by MY build.

---

# 33. PHASE 7 — INFRASTRUCTURE AUDIT

Inspect:

```text
infrastructure/environments/prod/
```

and all modules.

Trace exact dependencies.

Verify whether initial deployment requires:

```bash
terraform apply \
  -target=module.vpc \
  -target=module.gke
```

followed by:

```bash
terraform apply
```

because Helm/Kubernetes providers depend on the cluster.

Do not assume.

Verify code.

---

# 34. PHASE 8 — FINAL SCOPE DECISION

Deploy:

```text
VPC
GKE
GAR
GitHub WIF
Argo CD
Kyverno
demo application
Falco
runtime alerting
```

Do not deploy unless required:

```text
Gatekeeper
Ratify
VEX
cert-manager
ExternalDNS
custom domain
monitoring stack
```

Prefer disabling unused infrastructure via configuration rather than deleting its source.

---

# 35. PHASE 9 — SEARCH ALL UPSTREAM-SPECIFIC REFERENCES

Run repository-wide searches including `infrastructure/`.

At minimum search:

```bash
git grep -niE \
'musaumakau|stoked-citizen|europe-west1-docker.pkg.dev'
```

Also search:

```text
old GitHub repository URLs
old GCP project IDs
old service accounts
GAR paths
workflow identities
SLSA source URIs
Argo repoURLs
Discord webhook placeholders
old two-repo README links
gcp-infrastructure-modules
supply-chain-security.git
```

Classify findings:

```text
runtime config
policy identity
documentation
test fixture
historical evidence
monorepo integration reference
```

Do NOT blindly replace historical evidence.

---

# 36. NEW MONOREPO IDENTITY

The repository identity used for all NEW runtime trust should be the canonical GitHub monorepo:

```text
OWNER/gcp-supply-chain-security
```

Determine `OWNER` from actual `origin`.

Do not assume.

This identity should eventually drive:

```text
WIF repository condition
Cosign certificate identity
SLSA source URI
Kyverno trusted workflow identity
Argo CD repo URL
branch protection
README links
```

This is especially important because the upstream application was previously:

```text
musaumakau/supply-chain-security
```

and the final repository name is different.

---

# 37. PHASE 10 — GCP AUTHENTICATION

Check:

```bash
gcloud auth list
gcloud config get-value project
gcloud projects list
```

If login is missing:

output:

```text
=== ACTION REQUIRED FROM USER ===

Run:

gcloud auth login
gcloud auth application-default login

Then reply:
continue
```

Do not guess project.

Do not silently switch projects.

---

# 38. PHASE 11 — GCP PROJECT / REGION

Once known, record:

```text
PROJECT_ID
PROJECT_NUMBER
REGION
```

Prefer retaining upstream region where practical to minimize changes.

If existing configuration uses:

```text
europe-west1
```

keep it unless:

* quota issue
* unsupported service
* user requirement
* meaningful credit/cost reason

---

# 39. PHASE 12 — REQUIRED APIs

Determine exact APIs from executable code.

Likely candidates include:

```text
compute.googleapis.com
container.googleapis.com
artifactregistry.googleapis.com
iam.googleapis.com
iamcredentials.googleapis.com
sts.googleapis.com
cloudresourcemanager.googleapis.com
serviceusage.googleapis.com
pubsub.googleapis.com
cloudfunctions.googleapis.com
run.googleapis.com
eventarc.googleapis.com
storage.googleapis.com
```

Enable only what is required.

Document actual enabled services.

---

# 40. PHASE 13 — TERRAFORM BACKEND

Terraform working root is now expected somewhere under:

```text
infrastructure/environments/prod/
```

Use the actual code.

Use GCS remote state.

Create/choose a state bucket with:

```text
versioning
appropriate location
unique name
```

Never commit credentials.

Record state location.

---

# 41. PHASE 14 — TERRAFORM TFVARS

Use:

```text
infrastructure/environments/prod/terraform.tfvars.example
```

if present.

Create local:

```text
infrastructure/environments/prod/terraform.tfvars
```

using only supported variables.

Keep it ignored.

Never commit:

```text
Discord webhook
service-account JSON
private keys
```

---

# 42. PHASE 15 — COST REVIEW

Before apply inspect:

```text
regional GKE
node pools
machine types
disk sizes
Cloud NAT
load balancers
Falco
Cloud Function
Pub/Sub
```

Record major cost drivers.

Do not aggressively shrink everything before the first successful deployment.

If minimal safe cost reductions exist:

document and apply only if they don't create deployment risk.

---

# 43. PHASE 16 — TERRAFORM VALIDATION

From actual infrastructure environment root run:

```bash
terraform fmt -recursive
terraform init
terraform validate
terraform plan
```

Fix genuine errors only.

Do not refactor working modules just for style.

Record:

```text
add
change
destroy
```

counts.

No unexplained destructive changes.

---

# 44. PHASE 17 — GKE DEPLOYMENT

If two-pass deployment is required:

first deploy:

```text
VPC
GKE
```

then obtain cluster credentials.

Verify:

```bash
kubectl get nodes
kubectl get pods -A
```

Nodes must become:

```text
Ready
```

Then run the second Terraform apply.

Verify actual installed components.

Never assume Kyverno exists just because a README says so.

---

# 45. PHASE 18 — GAR

Determine whether Terraform creates GAR.

If yes:

reuse compatible existing module output.

If no:

create the expected repository.

Desired concept:

```text
REGION-docker.pkg.dev/
PROJECT_ID/
supply-chain-security/
supply-chain-demo
```

Avoid unnecessary naming changes.

Record actual GAR URL.

---

# 46. PHASE 19 — GITHUB ACTIONS → GCP WIF

Final authentication:

```text
GitHub Actions
 ↓
GitHub OIDC
 ↓
GCP STS
 ↓
Workload Identity Federation
 ↓
short-lived service-account credentials
 ↓
GAR
```

No long-lived CI JSON key.

Create dedicated CI SA.

Prefer minimum scope such as:

```text
roles/artifactregistry.writer
```

on the relevant repository.

Add only additional IAM roles proven necessary.

---

# 47. WIF REPOSITORY CONDITION

Because this is now a monorepo, the repository condition must trust:

```text
OWNER/gcp-supply-chain-security
```

NOT:

```text
musaumakau/supply-chain-security
```

and NOT:

```text
OWNER/supply-chain-security
```

unless the actual remote name differs.

Derive actual repo identity from:

```bash
git remote get-url origin
```

Use an attribute condition equivalent to:

```text
assertion.repository == "OWNER/gcp-supply-chain-security"
```

using the real value.

---

# 48. PHASE 20 — GITHUB VARIABLES

Inspect active root workflows for exact names.

Likely:

```text
GCP_WORKLOAD_IDENTITY_PROVIDER
GCP_SA_EMAIL
```

Use:

```bash
gh auth status
```

If authenticated, Codex may configure appropriate repository variables.

Do not place non-secret WIF identifiers into secrets unless the workflow requires it.

---

# 49. PHASE 21 — UPDATE CI FOR MONOREPO IDENTITY

Update root active application workflows with MY:

```text
GCP project
GAR repository
region
GitHub monorepo identity
```

Preserve:

```text
SHA tagging
digest outputs
keyless signing architecture
```

Do not switch GAR to Docker Hub/GHCR.

---

# 50. MONOREPO PATH FILTERS

Because infrastructure now exists inside the same repo:

review root workflow triggers carefully.

Application CI should not unnecessarily run because only:

```text
infrastructure/**
```

changed, unless required.

Infrastructure CI, if activated, should not unnecessarily run for every app/docs change.

Use sensible `paths:` / `paths-ignore:` only where they improve correctness.

Do not create trigger loops.

---

# 51. PHASE 22 — UPDATE KYVERNO TRUST IDENTITY

This is CRITICAL.

Update policy runtime trust from upstream to the final monorepo.

All relevant references should use:

```text
OWNER/gcp-supply-chain-security
```

and MY:

```text
GCP project
GAR path
workflow identity
source URI
```

Trusted workflow should correspond to the actual root signing workflow, e.g.:

```text
.github/workflows/sign-attest.yml
```

on:

```text
main
```

in the final monorepo.

---

# 52. VERIFY THREE KYVERNO TRUST DIMENSIONS

## Signature

Validate:

```text
certificate identity
OIDC issuer
GAR scope
verifyDigest
```

## SBOM

Validate:

```text
predicate/attestation type
trusted workflow identity
image scope
```

## SLSA provenance

Validate:

```text
predicate type
entryPoint
source repository
builder/workflow identity
image scope
```

Use existing tests.

Do not rewrite policy from scratch.

---

# 53. PHASE 23 — POLICY TESTS

Run existing tests.

Update fixtures only when they intentionally represent new runtime repository identity.

Do not rewrite historical evidence.

Validate:

```text
JMESPath
workflow identity
source repo
provenance
negative cases
```

---

# 54. PHASE 24 — KYVERNO

If infrastructure does not install Kyverno:

install current official Kyverno Helm chart.

Use:

```text
namespace: kyverno
```

The upstream project historically needed:

```text
maxContextSize = 8Mi
```

because attestation context was large.

Verify whether current Kyverno still requires this.

If needed:

configure through Helm.

Do not manually patch generated config.

Do NOT apply Enforce policy before a trusted artifact exists.

---

# 55. PHASE 25 — ARGO CD

If not installed:

install current official Argo CD Helm chart.

Use:

```text
namespace: argocd
```

No custom domain.

No TLS infrastructure.

Use port-forward for UI.

Verify Argo components healthy.

---

# 56. PHASE 26 — UPDATE ARGO REPOSITORY IDENTITY

Change:

```text
argocd/supply-chain-demo-app.yaml
argocd/supply-chain-test-negative-app.yaml
```

to reference the new canonical monorepo.

Expected:

```text
https://github.com/OWNER/gcp-supply-chain-security.git
```

Happy-path Application:

```text
automated sync
prune
selfHeal
```

Negative-test Application:

preserve deliberate non-automatic/failure semantics.

Never allow intentionally invalid manifests to auto-deploy continuously.

---

# 57. PHASE 27 — PR SECURITY TEST

Create harmless application change.

Open PR.

Validate:

```text
Semgrep
Trivy filesystem scan
policy/unit tests if configured
```

Do not bypass failures.

Record GitHub run links/IDs.

---

# 58. PHASE 28 — MAIN BUILD

Main pipeline should produce:

```text
build
 ↓
GAR
 ↓
Trivy image scan
 ↓
Cosign keyless signature
 ↓
SPDX SBOM
 ↓
SLSA provenance
 ↓
verification
```

Validate every stage.

Record:

```text
Git commit SHA
image tag
image digest
workflow run
```

---

# 59. PHASE 29 — TRUSTED DIGEST

Do not use upstream digest.

Once MY pipeline succeeds:

obtain MY immutable:

```text
sha256:...
```

Update:

```text
k8s/helm/supply-chain-demo/values.yaml
```

with MY:

```text
GAR repository
digest
```

Do not use `latest`.

---

# 60. PHASE 30 — MANUAL COSIGN CHECK

Even though CI verifies automatically, manually validate at least:

```text
signature
SBOM
SLSA provenance
```

for MY digest.

Record concise evidence.

---

# 61. PHASE 31 — APPLY KYVERNO POLICY

Only after trusted artifact exists.

Apply:

```text
policy/kyverno/block-unsigned-images.yaml
```

Verify policy is enforcing.

Do NOT change to Audit mode merely to make deployment easier.

---

# 62. PHASE 32 — TRUSTED ARGO DEPLOYMENT

Apply happy-path Argo Application.

Validate:

```text
Synced
Healthy
Pod Ready
Service available
```

Trusted image must pass Kyverno.

If it fails:

debug trust identity.

Do NOT weaken policy.

Investigate:

```text
certificate identity
OIDC issuer
repository name
workflow path
digest
attestation
source URI
Kyverno context size
```

---

# 63. PHASE 33 — APPLICATION TEST

Inspect application source for real endpoints.

Expected upstream endpoints may include:

```text
/
/health
/info
```

but verify source.

Use port-forward where possible.

Do not invent endpoints.

---

# 64. PHASE 34 — UNSIGNED IMAGE NEGATIVE TEST

Test inside the SAME protected GAR scope.

Do not use arbitrary Docker Hub nginx if policy doesn't match it.

Push/create disposable unsigned artifact under protected repository.

Attempt admission.

Expected:

```text
BLOCK
```

Record exact Kyverno error.

---

# 65. PHASE 35 — INVALID PROVENANCE/IDENTITY TEST

Use existing negative-test mechanism where practical.

Expected:

```text
BLOCK
```

Record which trust condition failed.

---

# 66. PHASE 36 — INITCONTAINER BYPASS TEST

Use existing negative test if present.

Scenario:

```text
trusted main container
+
unsigned/untrusted initContainer
```

Expected:

```text
BLOCK
```

Do not claim protection until actually tested.

---

# 67. FINAL ADMISSION MATRIX

Validate:

| Scenario                               | Expected |
| -------------------------------------- | -------- |
| Trusted signed + attested digest       | ADMIT    |
| Unsigned protected image               | BLOCK    |
| Invalid identity/provenance            | BLOCK    |
| Trusted main + untrusted initContainer | BLOCK    |

---

# 68. PHASE 37 — FALCO

Determine actual current deployment from:

```text
infrastructure/falco/
```

Verify:

```text
driver
DaemonSet
Falcosidekick
rules
allowlists
```

Do not assume `modern_ebpf`; verify.

Check pods and logs.

---

# 69. PHASE 38 — FALCO ALERTING AUTH

Preferred:

```text
GKE Workload Identity
```

If supported.

Fallback only if proven necessary:

```text
dedicated minimally privileged GCP JSON key
```

for Falcosidekick.

Never reuse GitHub Actions CI SA.

Never commit key.

Document the limitation.

---

# 70. PHASE 39 — SAFE RUNTIME TEST

Use a controlled event known to trigger an existing Falco rule.

Potential example:

```text
kubectl exec
```

but inspect current rules first.

Do not run destructive or privileged attack simulations.

Record:

```text
rule
priority
pod
namespace
timestamp
```

---

# 71. PHASE 40 — EXTERNAL RUNTIME ALERT

If retained architecture is:

```text
Falco
 ↓
Falcosidekick
 ↓
Pub/Sub
 ↓
Cloud Function
 ↓
Discord
```

validate every hop.

Inspect:

```text
Falco logs
Falcosidekick logs
Pub/Sub
Cloud Function logs
Discord
```

Do not claim end-to-end alerting until notification is actually received.

---

# 72. PHASE 41 — GITHUB BRANCH PROTECTION

Root:

```text
terraform/
```

may contain GitHub ruleset Terraform.

Audit whether it is worth applying to the NEW monorepo.

Desired:

```text
main protected
PR checks required
security checks required
```

Optional.

Do not allow account/plan limitations here to block the main project.

---

# 73. PHASE 42 — SECRET SAFETY

Before every commit inspect for:

```text
terraform.tfvars
tfstate
GCP service-account JSON
Discord webhook
GitHub PAT
kubeconfig
temporary OIDC tokens
Cosign temporary material
Cloud Function secrets
```

Because this is a monorepo, inspect BOTH:

```text
root
infrastructure/
```

Also verify both:

```text
.gitignore
infrastructure/.gitignore
```

behavior.

Never commit credentials.

---

# 74. PHASE 43 — PERSONAL EVIDENCE

Create:

```text
docs/my-validation/
```

Do NOT use upstream screenshots as mine.

Required evidence:

```text
01-pr-security-gates.png
02-main-build-pipeline.png
03-gar-image-digest.png
04-cosign-verification.png
05-sbom-provenance-verification.png
06-gke-workloads.png
07-argocd-healthy.png
08-trusted-image-admitted.png
09-unsigned-image-blocked.png
10-invalid-provenance-blocked.png
11-init-container-bypass-blocked.png
12-falco-runtime-detection.png
13-runtime-alert.png
```

Maintain:

```text
docs/codex/08-SCREENSHOT-CHECKLIST.md
```

For each explain:

```text
where
what should be visible
why it matters
what sensitive data to hide
```

---

# 75. PHASE 44 — README REWRITE

Only after validation.

Final title:

# GCP Software Supply Chain & Runtime Security

README must explicitly describe the monorepo:

```text
/
├── application/security pipeline
└── infrastructure/
    └── GCP/GKE/runtime-security infrastructure
```

Required sections:

```text
Overview
Problem
Architecture
Monorepo Structure
Trust Chain
Technology Stack
GCP Infrastructure
GitHub Actions CI
Workload Identity Federation
Artifact Registry
Vulnerability Scanning
Keyless Signing
SBOM
SLSA Provenance
Verification
GitOps Deployment
Kyverno Admission Control
Runtime Security with Falco
Validation Matrix
Failure Tests
Screenshots
Deployment Guide
Cleanup
Design Decisions
Limitations
Repository History / Upstream Credits
```

---

# 76. README MUST EXPLAIN MONOREPO HISTORY

Include a concise section explaining:

```text
The project combines two upstream reference repositories into one monorepo.

Application/security upstream:
musaumakau/supply-chain-security

Infrastructure upstream:
musaumakau/gcp-infrastructure-modules

Both original Git histories were preserved using a two-parent merge.
Infrastructure is retained under /infrastructure.
```

Link:

```text
docs/repository-merge.md
```

for details.

Do not make the merge the main project story.

It is provenance information.

---

# 77. README CLAIM SAFETY

Correct:

```text
Validated Kyverno rejection of an unsigned image.
```

Incorrect:

```text
Prevents all software supply-chain attacks.
```

Correct:

```text
Cosign validates that an artifact was signed by the configured trusted GitHub Actions identity.
```

Incorrect:

```text
Signed images are guaranteed safe.
```

Correct:

```text
The SBOM records software inventory generated during CI.
```

Incorrect:

```text
SBOM proves there are no vulnerabilities.
```

---

# 78. FINAL ARCHITECTURE DIAGRAM

Create Mermaid based on ACTUAL final implementation.

Also create separate monorepo structure diagram:

```text
gcp-supply-chain-security
│
├── app/security/CI/GitOps
│
└── infrastructure/
    ├── VPC
    ├── GKE
    ├── Falco
    └── alerting
```

Do not show components that were not deployed.

---

# 79. UPSTREAM CREDIT

Preserve all license information.

Inspect license files at:

```text
root
infrastructure/
```

Do not consolidate or replace licenses unless legally appropriate and intentionally required.

README must credit both upstream repositories.

My contributions should be described honestly, for example:

```text
combined the two components into a history-preserving monorepo

configured my GCP environment

adapted GitHub WIF for the new monorepo identity

adapted GAR configuration

adapted Cosign/Kyverno trusted repository identities

deployed GKE infrastructure

deployed Kyverno admission enforcement

validated signature/SBOM/provenance

validated negative admission scenarios

validated Falco runtime detection/alerting

documented deployment and testing
```

---

# 80. PHASE 45 — FINAL VALIDATION

## Git history

Validate again:

```bash
git merge-base --is-ancestor \
  cf131149fd7f3c052c04875b21979e75b44c1d93 \
  HEAD

git merge-base --is-ancestor \
  d15ce7522d4c175f6dcba8b1082dd0a781c4160d \
  HEAD
```

Both pass.

---

## Terraform

From actual environment root:

```text
fmt
validate
plan
```

No unexplained drift.

---

## GKE

Validate:

```text
nodes Ready
Kyverno healthy
Argo CD healthy
application healthy
Falco healthy
```

---

## CI

Validate:

```text
PR checks
main build
GAR push
Trivy
Cosign
SBOM
SLSA
verification
```

---

## Admission

Validate:

```text
trusted → admit
unsigned → block
wrong provenance → block
bad initContainer → block
```

---

## Runtime

Validate:

```text
Falco detection
external alert
```

---

# 81. PHASE 46 — CREATE `docs/RESUME.md`

Project title:

# GCP Software Supply Chain & Runtime Security

Stack:

```text
GCP | GKE | Terraform | GitHub Actions | Workload Identity Federation | GAR | Docker | Semgrep | Trivy | Cosign | Syft | SLSA | Kyverno | Argo CD | Falco
```

Create 3–4 resume bullets based ONLY on validated work.

Good themes:

```text
GCP WIF
security gates
immutable artifact delivery
Cosign
SPDX SBOM
SLSA provenance
Kyverno
Falco
```

Do not invent percentages.

Use real counts only after validating them.

---

# 82. PHASE 47 — CREATE `docs/INTERVIEW-PREP.md`

For every question provide:

```text
Short answer
Deep explanation
Where it exists in monorepo
How I validated it
Typical failure mode
```

Cover at minimum:

1. What problem does the project solve?
2. Why is it one monorepo?
3. Why is infrastructure under `/infrastructure`?
4. Why were both upstream histories preserved?
5. What is software supply-chain security?
6. Semgrep vs Trivy.
7. What is GAR?
8. SHA tag vs digest.
9. Why not `latest`?
10. GitHub OIDC.
11. GCP Workload Identity Federation.
12. Why no CI service-account JSON key?
13. CI IAM permissions.
14. What Cosign signs.
15. Keyless signing.
16. Fulcio.
17. Rekor.
18. SBOM.
19. SPDX.
20. Syft.
21. SLSA.
22. Provenance.
23. Signature vs SBOM vs provenance.
24. Why all three.
25. Kyverno.
26. Kubernetes admission.
27. `verifyImages`.
28. `verifyDigest`.
29. GitHub workflow identity.
30. Why any valid Cosign signature is not enough.
31. Provenance source validation.
32. unsigned-image test.
33. invalid-provenance test.
34. initContainer test.
35. Argo CD.
36. GitOps.
37. Falco.
38. eBPF.
39. admission security vs runtime security.
40. Falcosidekick.
41. runtime alerting.
42. why Gatekeeper/Ratify was excluded.
43. limitations.
44. does signing mean safe?
45. does SBOM mean vulnerability free?
46. signing workflow compromise.
47. external Sigstore availability.
48. production improvements.

---

# 83. PHASE 48 — LIMITATIONS

Document honestly:

```text
demo workload is intentionally simple

signature proves trusted signing/build identity, not code safety

SBOM records inventory, not absence of vulnerabilities

policy trusts configured GitHub workflow identity

Sigstore availability matters

Falcosidekick may require a scoped static-key exception

single environment

no full observability stack

no HA workload design

upstream unused implementations are preserved but not deployed
```

---

# 84. PHASE 49 — CLEANUP PLAN

Create/update:

```text
docs/codex/07-COST-AND-CLEANUP.md
```

Include:

```text
negative test workloads
Argo Applications
Kyverno policies if needed
manual Helm installations
Terraform-managed infrastructure
GAR artifacts
WIF
GCS state
Falco credentials
Pub/Sub/Cloud Function resources
```

Do NOT run:

```text
terraform destroy
```

without explicit user approval.

---

# 85. STATIC KEY CLEANUP

If Falcosidekick required a JSON key:

track:

```text
service account
role
key ID
reason
```

Never private material.

Prepare revocation/deletion.

Verify no JSON key remains accidentally in the monorepo.

---

# 86. GAR CLEANUP

Document options:

```text
retain final trusted digest
delete negative images
delete obsolete tags
retain only useful evidence artifact
```

Do not delete final artifact without user decision.

---

# 87. MONOREPO COMMIT STRATEGY

There is now ONE commit history.

Do NOT create "application repo commits" and "infrastructure repo commits" as separate histories.

Use logical monorepo commits.

Examples:

```text
docs: audit monorepo and define implementation plan

chore: adapt monorepo configuration for GCP environment

ci: configure workload identity and artifact registry

ci: adapt workflows for monorepo paths

infra: configure GKE deployment environment

security: adapt Kyverno trust policy to monorepo identity

security: configure Falco runtime alerting

gitops: point Argo CD to monorepo desired state

docs: add security validation evidence

docs: finalize project documentation and interview guide
```

For infrastructure-specific changes, use:

```text
infra:
```

prefix.

For security:

```text
security:
```

Do not make dozens of tiny commits.

Do not rewrite pre-monorepo history.

---

# 88. PRESERVE THE MERGE BASELINE

The following commit represents the exact source combination:

```text
76c26bd21fb8ec6053b315cdb51580dfa3b62336
```

The following immediate post-merge commit documents it:

```text
3d29f6f7b03db8d2671b307d722454fbb1e0405d
```

All implementation should be easy to inspect as commits AFTER this baseline.

This separation is intentional:

```text
upstream histories
        ↓
history-preserving merge
        ↓
merge documentation
        ↓
MY implementation/adaptation commits
```

Preserve it.

---

# 89. DEBUGGING RULES

When failure occurs:

```text
1. Read exact error.
2. Identify layer.
3. Inspect current state.
4. Inspect logs/events.
5. Check identity/IAM.
6. Check monorepo paths.
7. Check repository identity.
8. Check GAR digest.
9. Check Cosign certificate identity.
10. Check attestation payload.
11. Check Kyverno logs.
12. Check Terraform state/module output.
13. Check Argo state.
14. Check Falco/Falcosidekick logs.
15. Consult current official docs if necessary.
16. Make smallest justified correction.
```

Do not redesign architecture immediately.

---

# 90. NEVER USE THESE WORKAROUNDS

If WIF fails:

```text
DO NOT replace GitHub CI with a JSON service-account key.
```

If Kyverno rejects trusted artifact:

```text
DO NOT change policy to Audit just to deploy.
```

If Argo fails:

```text
DO NOT bypass GitOps with kubectl apply and call it finished.
```

If Falco alerting fails:

```text
DO NOT fabricate evidence.
```

If monorepo paths break:

```text
fix path assumptions
```

rather than splitting the project back into two repos.

If README conflicts with code:

```text
FOLLOW EXECUTABLE CODE.
```

---

# 91. HUMAN ACTION POLICY

Proceed automatically unless genuine human action is required.

Stop for:

```text
gcloud login
GitHub login
GCP billing approval
GCP quota selection
Discord webhook creation
secret value unavailable to Codex
terraform destroy
other destructive cloud cleanup
```

Use:

```text
=== ACTION REQUIRED FROM USER ===

Phase:
...

Why:
...

Please do:
...

Commands/UI:
...

Then reply:
continue
```

---

# 92. STATUS MESSAGE AFTER EVERY PHASE

Output:

```text
=== PHASE COMPLETE ===

Phase:
Status:

Changed:
- ...

Validated:
- ...

Documentation updated:
- ...

Resources created:
- ...

Issues:
- ...

Next:
- ...
```

Before moving on update:

```text
docs/codex/02-PROJECT-STATUS.md
docs/codex/05-HANDOFF.md
```

---

# 93. SECRET SAFETY BEFORE EVERY COMMIT

Run:

```bash
git status
git diff
git diff --cached
```

Inspect root and infrastructure.

Never commit:

```text
GCP service-account JSON
terraform.tfvars
tfstate
Discord webhook
PAT
temporary cloud tokens
Cosign credentials/material
kubeconfig
Cloud Function secrets
```

---

# 94. DEFINITION OF DONE

The project is complete only when:

```text
[ ] Monorepo history integrity verified
[ ] Merge commit still has both original histories
[ ] docs/repository-merge.md preserved
[ ] Complete monorepo audit finished
[ ] README/code mismatches documented
[ ] Monorepo path issues documented/fixed
[ ] Implementation plan completed
[ ] Personal GitHub monorepo exists
[ ] origin points only to my repository
[ ] Nothing pushed to upstream repos

[ ] GCP project selected
[ ] APIs enabled
[ ] Terraform backend configured
[ ] Terraform fmt passes
[ ] Terraform validate passes
[ ] Terraform infrastructure deployed
[ ] GKE nodes Ready
[ ] GAR ready

[ ] GitHub WIF configured for MONOREPO identity
[ ] CI does not use GCP JSON key
[ ] PR Semgrep passes
[ ] PR Trivy passes

[ ] Docker build succeeds
[ ] SHA image pushed to GAR
[ ] Trivy image scan passes
[ ] Cosign signing succeeds
[ ] SBOM generated
[ ] SLSA provenance generated
[ ] Signature verification succeeds
[ ] SBOM verification succeeds
[ ] Provenance verification succeeds

[ ] Kyverno installed
[ ] Kyverno policy trusts new monorepo identity
[ ] Argo CD installed
[ ] Argo CD points to new monorepo
[ ] Helm points to my GAR digest
[ ] Trusted image admitted
[ ] Argo CD Healthy/Synced
[ ] Application reachable

[ ] Unsigned image blocked
[ ] Invalid identity/provenance blocked
[ ] Untrusted initContainer blocked

[ ] Falco healthy
[ ] Controlled runtime event detected
[ ] Runtime notification delivered

[ ] Validation matrix complete
[ ] Screenshot checklist complete
[ ] My screenshots captured
[ ] README rewritten for monorepo
[ ] Both upstream projects credited
[ ] Resume bullets generated
[ ] Interview guide generated
[ ] Cost/cleanup plan generated
[ ] No secrets committed
[ ] Final original-history ancestry checks pass
[ ] Teardown ready
```

---

# 95. YOUR FIRST ACTION NOW

DO NOT begin modifying Terraform, CI, Kyverno, or Argo CD yet.

Begin with:

# PHASE 0 — MONOREPO AUDIT + PLAN

Perform this order:

1. Confirm current directory is the combined monorepo.
2. Run `git status`.
3. Inspect current branch.
4. Inspect all remotes and push URLs.
5. Verify original app HEAD ancestry.
6. Verify original infra HEAD ancestry.
7. Verify merge commit still has two parents.
8. Read `docs/repository-merge.md`.
9. Inspect the monorepo tree.
10. Inspect root application/security files.
11. Inspect all ACTIVE root GitHub workflows.
12. Inspect all root composite GitHub Actions.
13. Inspect application/Dockerfile.
14. Inspect Kyverno policies.
15. Inspect retained Gatekeeper/Ratify code only to understand exclusions.
16. Inspect Argo CD.
17. Inspect Helm.
18. Inspect tests/fixtures.
19. Inspect GitHub ruleset Terraform.
20. Inspect upstream evidence/runbooks.
21. Inspect complete `infrastructure/` tree.
22. Inspect `infrastructure/environments/prod`.
23. Inspect VPC.
24. Inspect GKE.
25. Inspect Kubernetes add-ons.
26. Inspect Falco.
27. Inspect Falco alerting.
28. Inspect nested `infrastructure/.github/workflows`.
29. Determine which nested workflows, if any, should become active root workflows.
30. Compare all READMEs against executable implementation.
31. Verify Kyverno/add-ons documentation mismatch.
32. Verify current Falcosidekick GCP authentication capabilities.
33. Search every upstream-specific value across the monorepo.
34. Search every obsolete two-repository path/reference.
35. Identify monorepo-specific path problems.
36. Inspect GitHub remote status.
37. If no personal GitHub `origin` exists, safely prepare/create the new `gcp-supply-chain-security` repository.
38. Create/update all `docs/codex/` tracking files.
39. Write full monorepo audit.
40. Write complete implementation plan.
41. Update project status.
42. Update handoff.
43. Commit the audit/plan logically.
44. Only then begin implementation automatically.

Never split this project back into two repositories.

Never rewrite the preserved merge history.

Begin now.
