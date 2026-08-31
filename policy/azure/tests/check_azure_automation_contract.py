#!/usr/bin/env python3
"""Static contract checks for the Azure one-command convergence path."""

import re
from pathlib import Path

import yaml


REPO = Path(__file__).resolve().parents[3]
SCRIPT = REPO / "scripts/azure/apply-once.sh"
PROD_MAIN = REPO / "infrastructure/azure/environments/prod/main.tf"
PROD_VARS = REPO / "infrastructure/azure/environments/prod/variables.tf"
ADDONS = REPO / "infrastructure/azure/kubernetes-addons/main.tf"
APP = REPO / "argocd/supply-chain-azure-demo-app.yaml"
DEPLOY_WORKFLOW = REPO / ".github/workflows/azure-deploy.yml"
STATIC_WORKFLOW = REPO / ".github/workflows/azure-static-validation.yml"


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


script = SCRIPT.read_text()
prod_main = PROD_MAIN.read_text()
prod_vars = PROD_VARS.read_text()
addons = ADDONS.read_text()
deploy_text = DEPLOY_WORKFLOW.read_text()
static_text = STATIC_WORKFLOW.read_text()

for required in (
    "set -Eeuo pipefail",
    "--mode core|private",
    "TF_DATA_DIR",
    'mktemp -d',
    "-backend-config=use_azuread_auth=true",
    "terraform -chdir=\"$TF_ROOT\" apply -input=false \"$plan_file\"",
    "-target=module.private_runner",
    "PRIVATE_GITHUB_RUNNER_READY",
    "probe_private_api",
    "probe_private_service_endpoints",
):
    if required not in script:
        fail(f"apply-once.sh is missing {required!r}")

for forbidden in (
    "az aks get-credentials",
    "terraform apply -auto-approve",
    "ARM_CLIENT_SECRET",
    "ARM_CLIENT_CERTIFICATE",
):
    if forbidden in script:
        fail(f"apply-once.sh contains forbidden fallback/credential pattern: {forbidden}")

if "disable_public_network_access" not in prod_vars:
    fail("production root is missing the explicit public-service closure variable")
if "disable_public_network_access requires enable_private_endpoints" not in prod_main:
    fail("production root does not fail closed before endpoint creation")
if "public_network_access_enabled = !var.disable_public_network_access" not in prod_main:
    fail("child public-access flags are not driven by the closure gate")
if not re.search(r"virtual_network_subnet_id\s*=\s*module\.network\.functions_subnet_id", prod_main):
    fail("alerting Function VNet integration is not wired from the network module")
if "argocd_application" not in addons or "depends_on = [helm_release.argocd]" not in addons:
    fail("Terraform does not install the Argo Application after Argo CD")

app = yaml.safe_load(APP.read_text())
helm = app["spec"]["source"]["helm"]
automated = app["spec"]["syncPolicy"]["automated"]
if helm.get("ignoreMissingValueFiles") is not True:
    fail("Argo must tolerate a missing release values file during bootstrap")
if automated.get("prune") is not True or automated.get("selfHeal") is not True:
    fail("Argo must automatically reconcile the promoted release")
if app["spec"]["destination"]["server"] != "https://kubernetes.default.svc":
    fail("Argo must remain in-cluster and private")

deploy = yaml.safe_load(deploy_text)
promote = deploy["jobs"]["promote"]
if promote.get("permissions") != {"contents": "write"}:
    fail("only promote may receive contents: write")
if "id-token" in promote.get("permissions", {}):
    fail("promote must not receive Azure OIDC authority")
if promote.get("if") != "github.ref == 'refs/heads/main'":
    fail("promote must be main-only")
if "values.release.yaml.template" not in deploy_text:
    fail("promote must render the release template")
if "git add -- \"$release_file\"" not in deploy_text:
    fail("promote must stage only the release values file")
if "git push origin \"HEAD:refs/heads/main\"" not in deploy_text:
    fail("promote must push the verified release to main")
if "k8s/azure/**" in deploy_text:
    fail("broad chart path filters would recurse on the promotion commit")
if "^sha256:[0-9a-f]{64}$" not in deploy_text:
    fail("promote must require an exact sha256 digest")

static = yaml.safe_load(static_text)
static_permissions = static.get("permissions", static.get(True, {}).get("permissions", {}))
if static_permissions != {}:
    fail("static validation must default to no token permissions")
for job_name in ("yaml-and-policy", "terraform"):
    if static["jobs"][job_name].get("permissions") != {"contents": "read"}:
        fail(f"static validation job {job_name} must receive contents: read only")
if "id-token: write" in static_text or "azure/login" in static_text:
    fail("static validation must not have Azure authentication authority")
for required in (
    "check_azure_automation_contract.py",
    "scripts/azure/apply-once.sh --dry-run --mode core",
    "values.release.yaml",
):
    if required not in static_text:
        fail(f"static workflow is missing {required}")

print("Azure one-command automation contract checks passed.")
