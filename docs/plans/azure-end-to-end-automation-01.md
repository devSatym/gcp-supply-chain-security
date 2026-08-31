# Azure end-to-end automation plan

## Goal

Make the existing Azure implementation converge through one idempotent operator command, `scripts/azure/apply-once.sh`, using owner-supplied configuration from a private-network-capable host; the command will provision the private AKS platform, security controllers, Argo CD application, and optional private service closure, while the first verified `refs/heads/main` image is automatically promoted by GitHub Actions and reconciled by Argo without a manual `values.release.yaml` copy. This plan deliberately distinguishes “one command” from a literal single Terraform graph evaluation because the AzureRM backend must exist before it can be used, the private AKS API cannot be reached by Helm/Kubernetes providers until AKS and private DNS are ready, and Terraform must not build or invent an application release outside the trusted GitHub OIDC → sign/attest → verify → lock chain.

## Exact file scope

Only these paths may be created or edited by the implementation tasks:

- `scripts/azure/apply-once.sh` (new)
- `scripts/azure/README.md` (new)
- `infrastructure/azure/environments/prod/main.tf`
- `infrastructure/azure/environments/prod/variables.tf`
- `infrastructure/azure/environments/prod/outputs.tf`
- `infrastructure/azure/environments/prod/README.md`
- `infrastructure/azure/environments/prod/terraform.tfvars.example`
- `infrastructure/azure/falco-alerting/main.tf`
- `infrastructure/azure/falco-alerting/variables.tf`
- `infrastructure/azure/falco-alerting/README.md`
- `infrastructure/azure/kubernetes-addons/main.tf`
- `infrastructure/azure/kubernetes-addons/outputs.tf`
- `infrastructure/azure/kubernetes-addons/argocd-application-chart/Chart.yaml` (new)
- `infrastructure/azure/kubernetes-addons/argocd-application-chart/templates/application.yaml` (new)
- `argocd/supply-chain-azure-demo-app.yaml`
- `k8s/azure/supply-chain-demo/values.yaml`
- `k8s/azure/supply-chain-demo/values.release.yaml` (created only by the verified runtime promotion job; never hand-created with a fake digest)
- `k8s/azure/supply-chain-demo/values.release.yaml.example`
- `k8s/azure/supply-chain-demo/values.release.yaml.template` (new)
- `k8s/azure/supply-chain-demo/templates/deployment.yaml`
- `k8s/azure/supply-chain-demo/templates/service.yaml`
- `.github/workflows/azure-deploy.yml`
- `.github/workflows/azure-static-validation.yml`
- `policy/azure/tests/check_azure_gitops_contract.py`
- `policy/azure/tests/check_azure_automation_contract.py` (new)
- `docs/azure/README.md`
- `docs/azure/01-architecture-decisions.md`
- `docs/azure/02-setup.md`
- `docs/azure/03-validation-checklist.md`
- `docs/azure/04-live-validation-checklist.md`

Do not modify GCP infrastructure, GCP workflows, shared GCP policy tests, provider lock files, Terraform state, provider caches, binaries, or any path outside this list.

## Security invariants for every task

- GitHub → Azure remains OIDC-only. Do not add client secrets, service-principal passwords, ACR admin credentials, storage keys, Event Hubs connection strings, kubeconfigs, or webhook values to source, tfvars, state configuration, logs, or outputs.
- The only trusted release ref is exactly `refs/heads/main`; pull requests remain static/local validation only and never receive Azure login authority.
- AKS remains private with no public API fallback. Terraform Helm/Kubernetes work runs only from a host that can route to the private API and resolve its private DNS.
- Application deployment references only `repository@sha256:<digest>` after signature, SPDX SBOM, and SLSA provenance verification. Cosign metadata remains in its separate mutable repository.
- Discord remains opt-in. It is enabled only with `TF_VAR_discord_webhook_url` into the existing write-only Key Vault field; never add it to an example, generated file, output, or log.
- Subscription, tenant, region, globally unique names, Entra groups, private-runner details, GitHub configuration, and webhook values are owner inputs. Never invent them.
- Private ACR/service closure is not enabled until the private CI path is available. If the owner chooses the hosted-runner core mode, ACR remains authenticated but publicly reachable; AKS is still private.
- The implementer must not stage, commit, push, or clean repository state. The only planned runtime Git mutation is the narrowly scoped `promote` job’s `GITHUB_TOKEN` push of a verified release-values file; no implementation task may perform that push. No task generates provider caches or lock-file churn in the repository.

## Tasks

### Task 1 — Define the one-command convergence contract

#### File scope (create/edit only)

- `docs/azure/01-architecture-decisions.md`
- `docs/azure/02-setup.md`
- `infrastructure/azure/environments/prod/README.md`
- `infrastructure/azure/environments/prod/terraform.tfvars.example`
- `docs/azure/04-live-validation-checklist.md`

#### Steps

1. Document `scripts/azure/apply-once.sh` as the only normal operator entry point after the one-time remote-state bootstrap exists. It must be idempotent and non-interactive when all owner inputs are present.
2. Explain the internal convergence sequence without asking the operator to edit Terraform flags between phases: initialize the existing AzureRM backend, converge network/AKS/ACR identities, verify private AKS DNS reachability, install Kyverno/Falco/Argo plus the Argo Application, create optional private endpoints, probe them, and only then disable public access when private mode is explicitly selected.
3. Define two supported modes. `core` keeps ACR authenticated but publicly reachable so the existing hosted GitHub release jobs can operate; it still creates private AKS and all in-cluster controls. `private` requires an owner-approved private GitHub runner and closes ACR/alerting service public access only after endpoint/DNS checks. Neither mode may make the AKS API public.
4. State that bootstrap-state remains a one-time prerequisite because Terraform cannot initialize a backend that it creates in the same run. The wrapper may consume the resulting owner-supplied backend configuration, but it must not silently migrate, overwrite, or destroy existing local/remote state.
5. State that Terraform does not create a fake initial image. A running demo workload is reached by the trusted-main build → scan → sign/attest → verify → lock workflow, followed by automatic GitOps promotion. Until a real verified digest exists, Argo must remain healthy with no placeholder workload rather than attempting to run one.
6. Add an owner-input table covering subscription, tenant, region, names, Entra admin groups, backend configuration, prod var-file, private-runner readiness for `private`, GitHub repository variables and protected-main bot-push policy, and the optional Discord webhook. Mark live execution requiring these values as `BLOCKED_BY_EXTERNAL_INPUT`.
7. Add explicit fail-closed conditions: missing owner input, unreachable private AKS DNS, endpoint probe failure, unexpected Terraform replacement, non-digest image, missing attestation, public AKS access, or a secret appearing in output/logs.

#### Exact validation commands (offline)

```bash
python3 - <<'PY'
from pathlib import Path

paths = [
    Path("docs/azure/01-architecture-decisions.md"),
    Path("docs/azure/02-setup.md"),
    Path("infrastructure/azure/environments/prod/README.md"),
    Path("docs/azure/04-live-validation-checklist.md"),
]
text = "\n".join(path.read_text() for path in paths)
for required in (
    "apply-once.sh",
    "BLOCKED_BY_EXTERNAL_INPUT",
    "refs/heads/main",
    "private AKS",
    "TF_VAR_discord_webhook_url",
    "sha256",
):
    assert required in text, required
assert "literal single" in text or "one-time remote-state" in text
print("one-command contract and external-input guardrails are documented")
PY
git diff --check
```

#### Abort/rollback condition

Stop if the documentation implies zero-input Azure provisioning, a literal one-pass Terraform graph that bypasses the provider/backend constraints, a public AKS fallback, an automatic Discord default, a guessed cloud value, or a manual release-digest substitution. Preserve the existing staged/live evidence wording until the new flow is actually validated.

### Task 2 — Separate private-endpoint creation from public-access closure

#### File scope (create/edit only)

- `infrastructure/azure/environments/prod/main.tf`
- `infrastructure/azure/environments/prod/variables.tf`
- `infrastructure/azure/environments/prod/outputs.tf`
- `infrastructure/azure/environments/prod/README.md`
- `infrastructure/azure/environments/prod/terraform.tfvars.example`

#### Steps

1. Add a second, explicit convergence input such as `disable_public_network_access` (use the repository’s existing naming conventions if a better equivalent is chosen). Keep `enable_private_endpoints` responsible only for creating the ACR/Key Vault/Event Hubs/Function-storage endpoints.
2. Validate that `disable_public_network_access = true` requires `enable_private_endpoints = true`. Keep both defaults safe for the existing core mode. The first private-mode apply must be able to create services and endpoints while public access is still enabled; the final wrapper apply flips the public flags off.
3. Drive the supply-chain and alerting child modules from the new closure flag, not from endpoint-resource existence. Keep ACR admin and anonymous access disabled, Event Hubs local authentication disabled, and all existing identity scopes unchanged.
4. Correct the `registry_public_access_enabled` output and add non-secret outputs for the endpoint subnet, private DNS zone IDs, endpoint mode, and closure mode so the wrapper can preflight and report state without reading secrets or state contents.
5. Preserve the existing dependency direction and provider configuration. Do not add a public AKS host, `local_account_enabled`, static kubeconfig, or a Terraform resource that pretends to lock an ACR image.
6. Update the root README/example to show that `core` uses endpoints off and `private` uses two applies internally: endpoint creation/probe, then access closure. The operator must not hand-edit flags between them.

#### Exact validation commands (offline)

Run from temporary copies so no `.terraform/` directory or state is created in the repository:

```bash
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
cp -a infrastructure/azure "$tmp_dir/azure"
terraform fmt -check -recursive "$tmp_dir/azure"
for root in bootstrap-state network aks supply-chain kubernetes-addons falco falco-alerting environments/prod; do
  terraform -chdir="$tmp_dir/azure/$root" init -backend=false -input=false
  terraform -chdir="$tmp_dir/azure/$root" validate -no-color
done
git diff --check
```

#### Abort/rollback condition

Stop if any child module disables public access in the same desired resource creation that depends on an unprobed endpoint, if a closure flag can be true without endpoint creation, if a provider tries to contact Azure during backend-free validation, or if any sensitive value is added to an output/example. Do not change existing state or endpoint resources while repairing this task.

### Task 3 — Wire private Function networking and install the Argo Application in Terraform

#### File scope (create/edit only)

- `infrastructure/azure/falco-alerting/main.tf`
- `infrastructure/azure/falco-alerting/variables.tf`
- `infrastructure/azure/falco-alerting/README.md`
- `infrastructure/azure/environments/prod/main.tf`
- `infrastructure/azure/kubernetes-addons/main.tf`
- `infrastructure/azure/kubernetes-addons/outputs.tf`
- `infrastructure/azure/kubernetes-addons/argocd-application-chart/Chart.yaml`
- `infrastructure/azure/kubernetes-addons/argocd-application-chart/templates/application.yaml`

#### Steps

1. Add an optional Function VNet-integration subnet input to the alerting module and set `virtual_network_subnet_id` on the Linux Function App. Require the subnet whenever alerting service public access is disabled; leave alerting disabled by default. The prod root must pass `module.network.functions_subnet_id`.
2. Keep the Function’s identity-based Blob/Queue/Table host storage settings, Event Hubs managed-identity settings, Key Vault RBAC, and write-only webhook unchanged. Do not add a storage connection string, SAS, access key, or webhook output.
3. Add a small local Helm chart owned by the Kubernetes-addons module that installs the reviewed `argocd/supply-chain-azure-demo-app.yaml` as an Argo `Application` after the pinned Argo CD chart has installed its CRDs. Reuse the checked-in manifest through a Terraform `file`/`yamldecode` hand-off or an equivalent single-source mechanism; do not maintain two silently divergent application specs.
4. Make the Argo Application release status observable through a non-secret Terraform output. The application chart must be ordered after Argo CD, use the in-cluster API destination, and never create an ingress or public Argo service.
5. Keep the existing Kyverno policy Helm release ordering and Falco dependency ordering intact. The same private-network provider host must be able to reach the API for this one-command apply.

#### Exact validation commands (offline)

```bash
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
cp -a infrastructure/azure "$tmp_dir/azure"
for root in falco-alerting kubernetes-addons environments/prod; do
  terraform fmt -check -recursive "$tmp_dir/azure/$root"
done
terraform -chdir="$tmp_dir/azure/falco-alerting" init -backend=false -input=false
terraform -chdir="$tmp_dir/azure/falco-alerting" validate -no-color
terraform -chdir="$tmp_dir/azure/kubernetes-addons" init -backend=false -input=false
terraform -chdir="$tmp_dir/azure/kubernetes-addons" validate -no-color
terraform -chdir="$tmp_dir/azure/environments/prod" init -backend=false -input=false
terraform -chdir="$tmp_dir/azure/environments/prod" validate -no-color
helm lint infrastructure/azure/kubernetes-addons/policy-chart
helm lint infrastructure/azure/kubernetes-addons/argocd-application-chart
helm template argocd-application infrastructure/azure/kubernetes-addons/argocd-application-chart --set-json 'application={"apiVersion":"argoproj.io/v1alpha1","kind":"Application","metadata":{"name":"supply-chain-azure-demo","namespace":"argocd"}}'
git diff --check
```

#### Abort/rollback condition

Stop if the Function can run with private storage but has no VNet integration, if a private mode still needs public service access, if the application chart requires cluster-admin credentials or a public API, or if the generated chart duplicates and can drift from the reviewed Argo manifest. Do not weaken Kyverno or create a fake release values file.

### Task 4 — Implement the idempotent one-command Terraform runner

#### File scope (create/edit only)

- `scripts/azure/apply-once.sh`
- `scripts/azure/README.md`
- `infrastructure/azure/environments/prod/README.md`
- `docs/azure/02-setup.md`

#### Steps

1. Create a strict Bash entry point with `set -Eeuo pipefail`, explicit repository-root resolution, `--help`, `--mode core|private`, `--dry-run`, and required paths for the owner-supplied prod var-file and AzureRM backend configuration in normal mode. `--dry-run` may validate command selection without contacting Azure or requiring real input files. Never echo var-file contents or environment values; do not enable shell tracing.
2. Mark the script executable and run all Terraform data directories, saved plans, temporary backend material, and any local bootstrap artifacts under a `mktemp -d` directory outside the repository. Clean only that exact temporary directory on exit. Do not create `.terraform/`, `terraform.tfstate`, `*.tfplan`, or generated environment files in the worktree.
3. Initialize/reconfigure the already-bootstrapped prod backend with Azure AD/OIDC settings. Refuse to perform an implicit state migration or overwrite; require the existing recovery procedure and owner approval for a state migration.
4. Detect whether the foundation is absent or incomplete using state addresses only. For a new/incomplete state, save and apply a foundation plan targeting only network, private AKS, and supply-chain resources with add-ons/alerting/endpoints disabled. Apply exactly the saved plan, then verify that the private API FQDN resolves and port 443 is reachable from the runner without creating a kubeconfig.
5. Save and apply the convergence plan that enables workload add-ons and Argo Application. In `core`, leave endpoint creation and public-service closure disabled. In `private`, create endpoints while service public access remains enabled, run bounded private-DNS/connectivity probes for every enabled service, and only then save/apply the closure plan with `disable_public_network_access=true`.
6. Require `TF_VAR_discord_webhook_url` only when the explicit alerting input is enabled; otherwise force alerting off. Never print it, place it in a var-file, or write it to a generated file. If private mode is selected, require an explicit owner acknowledgement that the private GitHub release runner and GitHub variables are ready; do not silently fall back to hosted public runners after ACR closure.
7. End with non-secret Terraform outputs and a clear “infrastructure converged; trusted image release is next” status. A successful Terraform run must not claim the demo workload is healthy until Argo has received a real verified digest.
8. Document rerun/idempotency behavior and precise stop points for endpoint probe failure, unexpected replacement, provider/API reachability loss, policy installation failure, and secret detection.

#### Exact validation commands (offline)

```bash
bash -n scripts/azure/apply-once.sh
scripts/azure/apply-once.sh --help
scripts/azure/apply-once.sh --dry-run --mode core
git diff --check
```

#### Abort/rollback condition

Stop if the runner can only reach a public AKS endpoint, if the script uses `terraform apply` without a saved plan, `-auto-approve` on an unreviewed plan, `az aks get-credentials`, static credentials, a state migration, a guessed backend, or a public-service fallback. Leave remote state and live resources untouched when any preflight or probe fails.

### Task 5 — Make verified release promotion and Argo reconciliation automatic

#### File scope (create/edit only)

- `.github/workflows/azure-deploy.yml`
- `argocd/supply-chain-azure-demo-app.yaml`
- `k8s/azure/supply-chain-demo/values.yaml`
- `k8s/azure/supply-chain-demo/values.release.yaml.example`
- `k8s/azure/supply-chain-demo/values.release.yaml.template`
- `k8s/azure/supply-chain-demo/templates/deployment.yaml`
- `k8s/azure/supply-chain-demo/templates/service.yaml`
- `policy/azure/tests/check_azure_gitops_contract.py`

#### Steps

1. Add an inert base-chart gate, for example `workload.enabled: false`, so Argo can be installed during Terraform convergence without attempting to deploy placeholder `${...}` image strings. Wrap both Deployment and Service in that gate. The release template must set the gate true and contain only the ACR repository placeholders plus `${IMAGE_DIGEST}`.
2. Set the reviewed Argo Application to consume `values.release.yaml`, ignore that file only while it is absent, and use automated `prune`/`selfHeal` sync. It must remain private and target `https://kubernetes.default.svc`; no ingress or direct Helm deployment may be added.
3. Change the trusted-main `promote` job to render the release template only after build, scan, signature/SBOM/provenance verification, and digest locking have succeeded. Require exactly `sha256:[0-9a-f]{64}`, render the chart with the generated file, reject unresolved placeholders/tag references, and verify the rendered Deployment image is exactly `repository@sha256:<digest>`.
4. Have `promote` commit only the verified `k8s/azure/supply-chain-demo/values.release.yaml` using the normal GitHub token and push it to `main`. Give `contents: write` only to this job; it must have no Azure/id-token authority. If protected-main policy rejects the bot push, fail closed and leave the previous release untouched. Do not add a PAT, GitHub App secret, Azure secret, or webhook.
5. Remove `values.release.yaml` from the Azure image-build workflow’s push path filters so the generated promotion commit cannot recursively rebuild/sign/lock itself. Keep chart source, policy, Docker, and application changes on the trusted-main release path. PRs must continue to receive only local build/scan/static validation.
6. Preserve the separate mutable Cosign metadata repository and the order build → scan → sign/attest → verify → lock → promote. Do not let the promotion job call `kubectl`, `helm upgrade`, Terraform, or Azure login.
7. Update the GitOps contract test to check the inert-base behavior, missing-release handling, automated Argo sync, exact digest validation, one-file promotion diff, main-only authority, and the single-job `contents: write` exception.

#### Exact validation commands (offline)

```bash
python3 -m py_compile policy/azure/tests/check_azure_gitops_contract.py
python3 policy/azure/tests/check_azure_gitops_contract.py
helm lint k8s/azure/supply-chain-demo
helm template supply-chain-demo k8s/azure/supply-chain-demo > /tmp/azure-base-render.yaml
helm template supply-chain-demo k8s/azure/supply-chain-demo \
  --values k8s/azure/supply-chain-demo/values.release.yaml.example \
  > /tmp/azure-release-example-render.yaml
python3 - <<'PY'
from pathlib import Path
import yaml

base = [d for d in yaml.safe_load_all(Path('/tmp/azure-base-render.yaml').read_text()) if d]
release = [d for d in yaml.safe_load_all(Path('/tmp/azure-release-example-render.yaml').read_text()) if d]
assert not {d.get('kind') for d in base} & {'Deployment', 'Service'}
assert {'Deployment', 'Service'} <= {d.get('kind') for d in release}
for doc in release:
    if doc.get('kind') == 'Deployment':
        for container in doc['spec']['template']['spec']['containers']:
            assert '@sha256:' in container['image']
print('base render is inert and release render is digest-shaped')
PY
git diff --check
```

#### Abort/rollback condition

Stop if promotion can run on a PR/branch, if any job other than `promote` gets repository write authority, if a generated commit can modify files beyond the release values file, if Argo can render/deploy placeholders, if the job bypasses verification/locking, or if it needs a long-lived GitHub/Azure credential. Do not push or alter branch protection during implementation.

### Task 6 — Add the static automation contract and CI coverage

#### File scope (create/edit only)

- `policy/azure/tests/check_azure_automation_contract.py`
- `.github/workflows/azure-static-validation.yml`
- `docs/azure/03-validation-checklist.md`
- `docs/azure/README.md`

#### Steps

1. Add a repository-native Python contract test that reads the wrapper, prod Terraform, Kubernetes-addons chart, Argo manifest, Azure workflows, and GitOps test inputs. Check for: core/private mode gates, no public AKS, no secret/kubeconfig patterns, saved-plan sequencing, private-only provider assumptions, inert base chart, automatic Argo sync, exact main ref, PR no-cloud authority, and the one narrow promotion write permission.
2. Add the test and wrapper syntax/dry-run checks to `azure-static-validation.yml`. Keep the workflow’s top-level permission at `contents: read`; it must not log into Azure or run Terraform apply.
3. Extend the offline render assertions to cover both base and release chart behavior and the Terraform-installed Argo Application chart. Keep existing Kyverno, Falco, GCP-parity, and identity-consistency tests unchanged except for additive Azure assertions.
4. Record only commands actually run and results actually observed in the Azure validation docs. Separate static pass results from live release, private closure, and optional Discord results; do not relabel existing GCP evidence.

#### Exact validation commands (offline)

```bash
python3 -m py_compile policy/azure/tests/check_azure_automation_contract.py
python3 policy/azure/tests/check_azure_automation_contract.py
python3 policy/azure/tests/check_azure_gitops_contract.py
python3 policy/azure/tests/check_azure_policy_contract.py
python3 policy/azure/tests/check_falco_contract.py
bash -n scripts/azure/apply-once.sh
helm lint k8s/azure/supply-chain-demo
helm lint infrastructure/azure/kubernetes-addons/argocd-application-chart
git diff --check
```

Run the complete Azure Terraform backend-free validation from a temporary copy as specified in Task 2, then record the exact results.

#### Abort/rollback condition

Stop if a static test requires Azure credentials, a live AKS API, a webhook, a provider cache in the worktree, a generated lock file, or a change to GCP behavior. Do not weaken a test to accommodate an implementation that violates the security contract; repair the implementation or record it as blocked.

### Task 7 — Run the live end-to-end acceptance gate — `BLOCKED_BY_EXTERNAL_INPUT`

#### File scope (create/edit only after owner inputs are supplied)

- `docs/azure/03-validation-checklist.md`
- `docs/azure/04-live-validation-checklist.md`
- `docs/azure/README.md`
- `scripts/azure/README.md`

#### Steps

1. Do not start this task until the owner supplies and authorizes the Azure subscription/tenant/region/names, Entra admin groups, existing backend configuration, private-network execution host, GitHub repository variables, and protected-main promotion policy. Supply a Discord webhook only if alerting is explicitly in scope.
2. From the approved private host, run the wrapper in `core` or `private` mode and inspect each saved plan before its corresponding apply. Confirm the final no-drift plan has no unexpected replacement and the AKS API remains private.
3. Confirm Terraform-installed Argo CD and Application are Ready, the base chart creates no placeholder workload before release, and the first trusted-main workflow produces the exact chain build → scan → sign/attest → verify → lock → auto-promote.
4. Confirm Argo reconciles the bot-committed release values and the running Deployment contains only the verified ACR digest. Test unsigned, wrong-identity, wrong-provenance, mutable-tag, and signed-main/unsigned-init-container admission failures from the private host.
5. In `private` mode, verify ACR/Key Vault/Event Hubs/Function-storage private DNS and access from the correct VNet paths, then confirm no hosted-runner fallback is needed. If alerting is enabled, verify Falcosidekick/Event Hubs/Function managed-identity flow and Discord retrieval from write-only Key Vault without recording the URL.
6. Record Azure-only evidence and label each item `STATICALLY_VALIDATED`, `LIVE_VALIDATION_PENDING`, `LIVE_VALIDATED`, or `BLOCKED_BY_EXTERNAL_INPUT`. Do not claim the project is fully live while the first trusted image, private CI path, or optional webhook remains pending.

#### Exact validation commands (offline)

```bash
python3 - <<'PY'
from pathlib import Path
text = Path('docs/azure/04-live-validation-checklist.md').read_text()
for required in ('STATICALLY_VALIDATED', 'LIVE_VALIDATION_PENDING', 'LIVE_VALIDATED', 'BLOCKED_BY_EXTERNAL_INPUT', 'private', 'digest'):
    assert required in text, required
print('live checklist preserves static/live/blocker separation')
PY
git diff --check
```

The actual Terraform plan/apply, Azure CLI probes, private AKS checks, GitHub release run, Argo health checks, and optional Discord delivery are live validations and remain blocked until the listed owner inputs are explicitly supplied.

#### Abort/rollback condition

Abort before any live mutation if an owner input is missing, state migration is implicit, the private API/DNS path is unavailable, a plan proposes replacement of existing foundation resources, any public AKS endpoint appears, any secret is exposed, or the release chain cannot prove the exact trusted-main identity and digest. Do not destroy resources or delete state as part of this task.

Ready for implementation one task at a time.
