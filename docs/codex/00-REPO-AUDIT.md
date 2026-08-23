# Repository Audit

Audit date: 2026-08-23
Scope: complete monorepo, before implementation. No cloud resources were changed.

## Executive result

The repository is structurally a monorepo, its active remote is the intended personal repository, and current canonical history integrity **passes**. A previous audit blocker came from obsolete pre-rewrite SHA values in the master prompt and merge record. The canonical topology was independently verified; no history repair or implementation-time history rewrite was performed.

## Git and merge integrity

| Check | Result | Evidence |
| --- | --- | --- |
| Current branch / HEAD | `main` / `b90bcc75dae48231a04e2efcedc51eb70dfac89c` at verification | Local Git |
| Working tree at audit start | Only untracked `plan.md` | `git status --short` |
| Active remote | `origin` fetch/push: `https://github.com/devSatym/gcp-supply-chain-security.git` | `git remote -v` |
| Canonical merge | **PASS** | `6717e4491d3e8a2d0b6fd6044a673041f30d040c` is a commit with exactly two parents |
| Application-side parent | **PASS** | `cc1fa07a617320a8efdf31bb9aa67927128bd3a0` is a commit and an ancestor of `HEAD` |
| Infrastructure-side parent | **PASS** | `c88320f1b2ac1995aa1d75f481e1f69d7063c2ba` is a commit and an ancestor of `HEAD` |
| Post-merge documentation commit | **PASS** | `b90bcc75dae48231a04e2efcedc51eb70dfac89c` is a commit |
| Merge documentation | Corrected | [`docs/repository-merge.md`](../repository-merge.md) now records the current canonical topology |

Previous blocker: the master prompt referenced obsolete pre-rewrite SHA values. Resolution: validate the current canonical two-parent topology. History repair performed: **no**. History rewrite performed during this implementation: **no**.

## Monorepo layout and integration

```text
gcp-supply-chain-security/
├── app/, Dockerfile, .github/, policy/, argocd/, k8s/, terraform/
│   └── application/security layer
└── infrastructure/
    ├── environments/prod/, vpc/, gke/, kubernetes-addons/
    └── falco/, falco-alerting/, .github/
        └── infrastructure/runtime-security layer
```

The source component boundary is preserved as a directory boundary. The nested `infrastructure/.github/workflows/terraform.yml` is a retained upstream artifact; GitHub will not execute it because it is outside the root `.github/workflows/` directory.

## Application/security layer

### Application and image

- `app/main.py` is a three-endpoint FastAPI demonstration (`/`, `/health`, `/info`). `/info` reports build metadata but its `signed: true` value is a claim, not a runtime cryptographic verification.
- `Dockerfile` is a two-stage Python 3.12 Bookworm build, runs as UID/GID 10001, and has a health check. Its base image uses a mutable tag rather than a digest.
- The OCI source label still names `musaumakau/supply-chain-security` and must be updated only as part of the approved monorepo identity change.

### Active root GitHub Actions

| Workflow | Trigger / purpose | Audit result |
| --- | --- | --- |
| `pr-check.yml` | PRs to `main`; path detection, Semgrep, Trivy filesystem scan, policy tests | Active; checks application/security paths, not `infrastructure/**` |
| `security-scan.yml` | Reusable Semgrep and Trivy workflow | Semgrep uses a pinned container; SARIF upload is configured |
| `deploy.yml` | Push to `main` for `app/**`, Dockerfile, `.dockerignore`; manual confirmation | Calls build, SBOM/VEX, sign/attest, and verification |
| `build-push.yml` | Reusable GAR build/push and Trivy image scan | Has hardcoded upstream project `stoked-citizen-455416-g4` and GAR path |
| `sign-attest.yml` | Reusable keyless signature, SPDX SBOM, SLSA provenance | Generates provenance from `github.repository`; therefore it would produce the correct new URI after identity adaptation |
| `verify.yml` | Reusable Cosign signature/SBOM/provenance verification | Uses the actual calling repository for certificate identity, but hardcodes the upstream GAR project |
| `sbom-vex.yml` | Reusable CycloneDX/depscan report | Non-blocking and independent of the SPDX attestation in `sign-attest.yml` |

Root composites are `gcp-auth`, `setup-cosign`, `setup-syft`, and a retained `docker-login`. `gcp-auth` uses GitHub OIDC and `google-github-actions/auth`; it contains no service-account JSON key. `docker-login` is unused legacy Docker Hub functionality and should remain preserved, not activated.

The CI trust graph is: PR check → main `deploy.yml` → build/push (SHA tag/digest) → keyless signing + SBOM + provenance → Cosign verification. The first three artifact workflows all hardcode `europe-west1`, the former project ID, and the `supply-chain-security` GAR repository.

### Policy, GitOps, manifests, and tests

- `policy/kyverno/block-unsigned-images.yaml` is an Enforce `ClusterPolicy` with three rules: keyless signature, SPDX attestation, and SLSA provenance. It scopes enforcement to the upstream GAR repository, requires a digest, pins the upstream GitHub Actions subject/issuer, and tests provenance entrypoint, builder, and source URI. System/add-on namespaces are excluded.
- `policy/tests/check-identity-consistency.sh` passed. It proves the old workflow *path* is consistently `sign-attest.yml`, not that the owner/repository is correct for this monorepo.
- `policy/tests/test_jmespath_conditions.py` passed in an isolated temporary virtual environment against the captured upstream predicate. Its fixture deliberately contains the old upstream repository identity and must be updated together with the policy when the final identity is authorized.
- `policy/gatekeeper/` and Ratify files are retained comparison material. They reference the old GAR path and include a static-key mechanism. They are out of final deployment scope; no deletion is needed.
- Both Argo CD Applications point to `https://github.com/musaumakau/supply-chain-security.git`. The happy-path Application is automated with prune/self-heal; the negative test is deliberately manual.
- The Helm chart correctly renders a digest-pinned image but that image belongs to the old GAR project and is not personal validation. The direct manifest `k8s/manifests/deployment.yaml` has an invalid `@shasha256:` image reference.
- Existing files under `docs/evidence/` are historical upstream evidence. They are not personal validation and must be retained but not presented as new evidence.

### Repository-identity findings

Runtime configuration requiring adaptation includes workflow GAR IDs, Docker OCI source label, Kyverno trust subject and provenance URI, Argo CD `repoURL`, Helm image repository/digest, test fixture/manifests, root GitHub provider configuration, CODEOWNERS, and Renovate assignees/reviewers. Documentation, historical evidence, and merge attribution must be classified separately and not mass-replaced.

## Infrastructure/runtime-security layer

`infrastructure/environments/prod/` is the only deployable root module. It has a hardcoded GCS backend (`juan-makau-state-bucket`, prefix `gcp-infrastructure-modules/prod`), hardcoded former project defaults/examples, and an unconditional Falco/alerting/Ratify configuration. It needs an environment-specific backend and variables before any use in a new project.

| Component | Inputs / outputs | Resources and dependencies | Required in final scope? | Cost / audit notes |
| --- | --- | --- | --- | --- |
| `vpc` | Project, region, labels, private/public subnets; exports VPC/subnets/router/NAT IDs | VPC, subnets, flow logs, Cloud Router, Cloud NAT, firewalls; Google provider | Yes | Cloud NAT, logging, and network egress are material costs |
| `gke` | VPC output, regional setting, node pools, release channel; exports endpoint/CA/WI pool/credentials command | Regional private GKE control plane, node SAs/IAM, autoscaled node pools; Google/Google Beta | Yes | Regional control plane, nodes, disks, logging, managed Prometheus are material costs |
| `kubernetes-addons` | Cluster/provider connection, metrics and ExternalDNS switches | Optional metrics-server; ExternalDNS GSA, IAM, KSA, Helm release | No for this portfolio deployment | **Actual Terraform does not install Kyverno, Gatekeeper, or cert-manager.** ExternalDNS defaults to enabled and must be disabled in the final root configuration |
| `falco` | Pub/Sub topic, credentials, chart version, custom rules; exports namespace/release status | Namespace and Falco Helm release | Yes | DaemonSet uses node resources; chart currently pinned to 9.1.0 |
| `falco-alerting` | Project, region, Discord webhook; exports Pub/Sub topic/function/SA | Pub/Sub, Secret Manager secret/version, source bucket, Cloud Functions v2, function SA and IAM | Yes, after a webhook is supplied | Function/build storage, Pub/Sub, Secret Manager, and alert volume may incur cost |
| `environments/prod` | Wires modules and static identities | Also creates Falcosidekick and Ratify JSON service-account keys | Needs adaptation | Does not create GAR, GitHub WIF pool/provider, CI service account, or required APIs |

The documented add-ons mismatch is confirmed: `infrastructure/README.md` says `kubernetes-addons` deploys Kyverno, Gatekeeper, cert-manager, and ExternalDNS, while executable Terraform deploys only optional metrics-server and optional ExternalDNS. Final decision: install Kyverno separately by Helm after GKE is healthy; do not deploy Gatekeeper/Ratify, cert-manager, or ExternalDNS.

### Falcosidekick authentication audit

The checked chart is Falco `9.1.0`, whose dependency is Falcosidekick `0.12.*`. Its values declare `config.gcp.workloadIdentityServiceAccount`, the Kubernetes RBAC template annotates its deterministic service account with `iam.gke.io/gcp-service-account`, and Falcosidekick creates a Pub/Sub client with application-default credentials when `GCP_CREDENTIALS` is empty. The upstream module's claim that static JSON credentials are the only option is therefore stale.

Final intended design is GKE Workload Identity: bind the chart-created Falcosidekick KSA to a dedicated GSA with `roles/pubsub.publisher`, set `config.gcp.workloadIdentityServiceAccount`, and leave `credentials` empty. This must be validated in the deployed cluster before static-key Terraform is removed or a keyless claim is made. The existing Ratify static-key code remains preserved but excluded from deployment.

## Nested infrastructure workflow

`infrastructure/.github/workflows/terraform.yml` is **PRESERVE ONLY**. Besides being inactive when nested, it assumes the old repository root (`vpc`, `gke`, `kubernetes-addons`), uses broad `**.tf` filters, has outdated unpinned action references, lacks the actual `environments/prod` root, and its matrix cannot model that root's two-pass cluster dependency. If infrastructure CI is promoted later, create a new root workflow scoped to `infrastructure/**` and use `working-directory: infrastructure/environments/prod`; retain this original unchanged.

## Static validation performed

| Check | Result | Notes |
| --- | --- | --- |
| `git diff --check` | Pass | No whitespace errors before audit documentation |
| `helm template supply-chain-demo k8s/helm/supply-chain-demo` | Pass | Renders the old digest-pinned Helm image |
| Identity consistency shell test | Pass | Upstream subject path consistent across policy/CI consumers |
| Kyverno JMESPath fixture test | Pass | Tested against the upstream fixture in an isolated environment |
| `terraform fmt -check -recursive infrastructure terraform` | Fail | Only `terraform/main.tf` needs formatting; it also still targets upstream GitHub owner/repository |
| `terraform init -backend=false` / validate for `infrastructure/vpc` | Pass | Configuration valid with Google provider 7.45.0 selected locally |
| Remaining Terraform validates | Not completed | Deferred until the configuration is adapted for the selected GCP project; no cloud apply/plan ran |

## Documentation discrepancies to correct during implementation

1. Root and infrastructure READMEs describe two repositories and simultaneous Kyverno plus Gatekeeper/Ratify deployment; final scope is one monorepo and Kyverno only.
2. `infrastructure/README.md` incorrectly claims Kyverno, Gatekeeper, and cert-manager are provisioned by the add-ons module.
3. Falcosidekick documentation incorrectly claims the pinned chart lacks GKE Workload Identity support.
4. The deployable root does not provision GAR, CI WIF, or APIs despite root CI and policy requiring them.
5. Existing evidence contains old images, identities, and paths; it must be labelled historical rather than personal.

## Next implementation action

Proceed from the current canonical `main` history. First commit this audit and planning correction, then determine and confirm the actual GCP deployment project before adapting GAR, WIF, and infrastructure runtime configuration.
