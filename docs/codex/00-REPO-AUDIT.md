# Repository Audit

Audit date: 2026-08-23
Scope: complete monorepo, before implementation. No cloud resources were changed.

## Executive result

The repository is structurally a monorepo, its active remote is the intended personal repository, and current canonical history integrity **passes**. A previous audit blocker came from obsolete pre-rewrite SHA values in the master prompt and merge record. The canonical topology was independently verified; no history repair or implementation-time history rewrite was performed.

## Git and merge integrity

| Check | Result | Evidence |
| --- | --- | --- |
| Current branch / HEAD | `main` / implementation commits descend additively from the validated topology | Local Git |
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
- The OCI source label now uses `https://github.com/devSatym/gcp-supply-chain-security`; its base image remains tag-pinned rather than digest-pinned.

### Active root GitHub Actions

| Workflow | Trigger / purpose | Audit result |
| --- | --- | --- |
| `pr-check.yml` | PRs to `main`; path detection, Semgrep, Trivy filesystem scan, policy tests | Active; now treats `infrastructure/**` as security-relevant |
| `security-scan.yml` | Reusable Semgrep and Trivy workflow | Semgrep uses a pinned container; SARIF upload is configured |
| `deploy.yml` | Push to `main` for `app/**`, Dockerfile, `.dockerignore`; manual confirmation | Calls build, SBOM/VEX, sign/attest, and verification |
| `build-push.yml` | Reusable GAR build/push and Trivy image scan | Uses repository variables for GAR location/project/repository; it fails closed until the final variables are configured |
| `sign-attest.yml` | Reusable keyless signature, SPDX SBOM, SLSA provenance | Generates provenance from `github.repository`; therefore it would produce the correct new URI after identity adaptation |
| `verify.yml` | Reusable Cosign signature/SBOM/provenance verification | Uses the actual calling repository for certificate identity and the same fail-closed GAR repository variables |
| `sbom-vex.yml` | Reusable CycloneDX/depscan report | Non-blocking and independent of the SPDX attestation in `sign-attest.yml` |

Root composites are `gcp-auth`, `setup-cosign`, `setup-syft`, and a retained `docker-login`. `gcp-auth` uses GitHub OIDC and `google-github-actions/auth`; it contains no service-account JSON key. `docker-login` is unused legacy Docker Hub functionality and should remain preserved, not activated.

The CI trust graph is: PR check → main `deploy.yml` → build/push (SHA tag/digest) → keyless signing + SBOM + provenance → Cosign verification. The first three artifact workflows all hardcode `europe-west1`, the former project ID, and the `supply-chain-security` GAR repository.

### Policy, GitOps, manifests, and tests

- `policy/kyverno/block-unsigned-images.yaml` is an Enforce `ClusterPolicy` with three rules: keyless signature, SPDX attestation, and SLSA provenance. It currently scopes enforcement to the old GAR repository but now pins the canonical GitHub Actions subject and source URI; its GAR scope changes only after the GCP project is confirmed. It requires a digest and excludes system/add-on namespaces.
- `policy/tests/check-identity-consistency.sh` passed. It proves every checked signer consumer uses the `sign-attest.yml` workflow path; the active Kyverno subjects use the canonical repository identity.
- `policy/tests/test_jmespath_conditions.py` passed in an isolated temporary virtual environment against the canonical repository fixture.
- `policy/gatekeeper/` and Ratify files are retained comparison material. They reference the old GAR path and include a static-key mechanism. They are out of final deployment scope; no deletion is needed.
- Both Argo CD Applications now point to `https://github.com/devSatym/gcp-supply-chain-security.git`. The happy-path Application is automated with prune/self-heal; the negative test is deliberately manual.
- The Helm chart correctly renders a digest-pinned image but that image belongs to the old GAR project and is not personal validation. The retained direct manifest's malformed digest syntax was corrected; it still references the old GAR image pending the selected GCP project and personal build.
- Existing files under `docs/evidence/` are historical upstream evidence. They are not personal validation and must be retained but not presented as new evidence.

### Repository-identity findings

The canonical repository identity has been adapted in the Docker OCI source label, Argo CD `repoURL`s, Kyverno subject/provenance URI, policy fixture, root GitHub provider configuration, CODEOWNERS, and Renovate assignees/reviewers. Remaining runtime adaptation is limited to the selected GCP project's GAR/WIF/IAM values, the resulting personal digest, and dependent negative-test manifests. Documentation, historical evidence, and retained Gatekeeper/Ratify configuration remain classified separately and are not mass-replaced.

Classification before replacement:

- **Runtime trust/config:** Argo CD, Kyverno subject/provenance, OCI metadata, GitHub ruleset, and CI now use the canonical repository (CI's GAR fields are explicit repository variables).
- **GAR pending target project:** Helm values, active Kyverno image scope, retained direct manifest, and negative-test image references retain the old GAR path until a personal repository and digest exist; no project ID was guessed.
- **Test fixtures:** `policy/test-manifests/` remains a historical test set until it is regenerated for the personal GAR scope.
- **Evidence:** `docs/evidence/` remains intact and labelled historical; it is not personal validation.
- **Historical attribution / legacy configuration:** `docs/repository-merge.md`, the marked attribution section of `infrastructure/README.md`, and disabled Gatekeeper/Ratify material preserve source provenance without representing active runtime identity.

## Infrastructure/runtime-security layer

`infrastructure/environments/prod/` is the only deployable root module. It now accepts its GCS backend at `terraform init` time, has no former-project defaults, provisions the GAR/WIF/CI foundation, and makes runtime alerting and retained Ratify compatibility resources opt-in. It still requires an accepted project, state bucket, and a reviewed plan before any apply.

| Component | Inputs / outputs | Resources and dependencies | Required in final scope? | Cost / audit notes |
| --- | --- | --- | --- | --- |
| `vpc` | Project, region, labels, private/public subnets; exports VPC/subnets/router/NAT IDs | VPC, subnets, flow logs, Cloud Router, Cloud NAT, firewalls; Google provider | Yes | Cloud NAT, logging, and network egress are material costs |
| `gke` | VPC output, regional setting, node pools, release channel; exports endpoint/CA/WI pool/credentials command | Regional private GKE control plane, node SAs/IAM, autoscaled node pools; Google/Google Beta | Yes | Regional control plane, nodes, disks, logging, managed Prometheus are material costs |
| `kubernetes-addons` | Cluster/provider connection, metrics and ExternalDNS switches | Optional metrics-server; ExternalDNS GSA, IAM, KSA, Helm release | No for this portfolio deployment | **Actual Terraform does not install Kyverno, Gatekeeper, or cert-manager.** Root explicitly disables ExternalDNS by default |
| `falco` | Optional Pub/Sub topic/GSA, chart version, custom rules | Namespace, Falco Helm release, narrow ServiceAccount annotation patch | Yes | DaemonSet uses node resources; chart is pinned to 9.1.0 and receives no JSON key |
| `falco-alerting` | Project, region, Discord webhook; exports Pub/Sub topic/function/SA | Pub/Sub, Secret Manager secret/version, source bucket, Cloud Functions v2, function SA and IAM | Opt-in after a webhook is supplied | Function/build storage, Pub/Sub, Secret Manager, and alert volume may incur cost |
| `environments/prod` | Wires modules and supply-chain foundation | Required APIs, immutable GAR, dedicated CI GSA and repository-scoped GitHub WIF; Falcosidekick WI binding | Adapted; not applied | Backend and target project remain explicit human-approved inputs |

The documented add-ons mismatch is confirmed: `infrastructure/README.md` says `kubernetes-addons` deploys Kyverno, Gatekeeper, cert-manager, and ExternalDNS, while executable Terraform deploys only optional metrics-server and optional ExternalDNS. Final decision: install Kyverno separately by Helm after GKE is healthy; do not deploy Gatekeeper/Ratify, cert-manager, or ExternalDNS.

### Falcosidekick authentication audit

The checked chart is Falco `9.1.0`, whose embedded Falcosidekick dependency is `0.12.1`. That dependency's values do not offer a direct GKE annotation setting, but its deterministic ServiceAccount is `falco-falcosidekick` and Falcosidekick creates its Pub/Sub client with application-default credentials when `GCP_CREDENTIALS` is empty. The root now applies a narrow declarative annotation to that ServiceAccount and binds it to a dedicated GSA with GKE Workload Identity. The upstream static-key claim is therefore stale.

Final intended design is GKE Workload Identity: bind `falco-system/falco-falcosidekick` to a dedicated GSA with `roles/pubsub.publisher`, annotate the KSA, and leave `credentials` empty. This must be validated in the deployed cluster before a live keyless claim is made. The Falcosidekick static-key resource has been removed; retained Ratify compatibility code remains disabled by default.

## Nested infrastructure workflow

`infrastructure/.github/workflows/terraform.yml` is **PRESERVE ONLY**. Besides being inactive when nested, it assumes the old repository root (`vpc`, `gke`, `kubernetes-addons`), uses broad `**.tf` filters, has outdated unpinned action references, lacks the actual `environments/prod` root, and its matrix cannot model that root's two-pass cluster dependency. If infrastructure CI is promoted later, create a new root workflow scoped to `infrastructure/**` and use `working-directory: infrastructure/environments/prod`; retain this original unchanged.

## Static validation performed

| Check | Result | Notes |
| --- | --- | --- |
| `git diff --check` | Pass | No whitespace errors before audit documentation |
| `helm template supply-chain-demo k8s/helm/supply-chain-demo` | Pass | Renders the old digest-pinned Helm image |
| Identity consistency shell test | Pass | Upstream subject path consistent across policy/CI consumers |
| Kyverno JMESPath fixture test | Pass | Tested against the upstream fixture in an isolated environment |
| `terraform fmt -check -recursive infrastructure terraform` | Pass | Root GitHub ruleset Terraform and adapted infrastructure are formatted |
| `terraform init -backend=false` / validate for `infrastructure/environments/prod` | Pass | Full deploy root and transitive modules validate locally with Google 7.45.0, Helm 2.17.0, Kubernetes 2.38.0, and Archive 2.8.0 |
| Terraform plan/apply | Not completed | Requires an accepted project, dedicated backend, and explicit cloud-creation approval |

## Documentation discrepancies to correct during implementation

1. Root and infrastructure READMEs still contain some retained legacy explanatory material; active deployment instructions use the canonical monorepo and Kyverno-only scope.
2. `infrastructure/README.md` incorrectly claims Kyverno, Gatekeeper, and cert-manager are provisioned by the add-ons module.
3. Falcosidekick documentation was corrected to describe the ServiceAccount annotation patch and ADC path.
4. The deployable root now declares GAR, CI WIF, and required APIs; nothing has been applied.
5. Existing evidence contains old images, identities, and paths; it must be labelled historical rather than personal.

## Next implementation action

Proceed additively from the current canonical `main` history. Review the pending Terraform changes, then request explicit approval of the candidate project, state bucket/location, and billable resource creation before running a plan or apply against GCP.
