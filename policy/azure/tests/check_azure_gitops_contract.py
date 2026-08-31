#!/usr/bin/env python3
"""Check the reviewed Azure Argo CD and digest-promotion contract."""

import sys
import re
from pathlib import Path

try:
    import yaml
except ImportError:
    print("pyyaml is required: python3 -m pip install pyyaml", file=sys.stderr)
    sys.exit(2)


REPO = Path(__file__).resolve().parents[3]
APP = REPO / "argocd/supply-chain-azure-demo-app.yaml"
BASE_VALUES = REPO / "k8s/azure/supply-chain-demo/values.yaml"
EXAMPLE_VALUES = REPO / "k8s/azure/supply-chain-demo/values.release.yaml.example"
RELEASE_TEMPLATE = REPO / "k8s/azure/supply-chain-demo/values.release.yaml.template"
WORKFLOW = REPO / ".github/workflows/azure-deploy.yml"


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


app = yaml.safe_load(APP.read_text())
source = app["spec"]["source"]
helm = source["helm"]
if source["repoURL"] != "https://github.com/devSatym/gcp-supply-chain-security.git":
    fail("Azure Argo CD must use the canonical repository")
if source["targetRevision"] != "main" or source["path"] != "k8s/azure/supply-chain-demo":
    fail("Azure Argo CD must track the reviewed Azure chart on main")
if helm.get("valueFiles") != ["values.release.yaml"]:
    fail("Azure Argo CD must consume only the reviewed release values file")
if app["spec"]["destination"]["server"] != "https://kubernetes.default.svc":
    fail("Azure Argo CD must target the in-cluster Kubernetes API")
if helm.get("ignoreMissingValueFiles") is not True:
    fail("Azure Argo must tolerate the absent release values file during bootstrap")
sync_policy = app["spec"].get("syncPolicy", {})
automated = sync_policy.get("automated", {})
if automated.get("prune") is not True or automated.get("selfHeal") is not True:
    fail("Azure Argo must automatically prune and self-heal the promoted release")
if automated.get("allowEmpty") is not False:
    fail("Azure Argo must not accept an empty application")

base = yaml.safe_load(BASE_VALUES.read_text())
if base["image"]["repository"] != "${ACR_LOGIN_SERVER}/${ACR_APPLICATION_REPOSITORY}":
    fail("the base Azure chart must remain placeholder-safe")
if base["image"]["digest"] != "${IMAGE_DIGEST}":
    fail("the base Azure chart must remain digest-shaped")
if base.get("workload", {}).get("enabled") is not False:
    fail("the base Azure chart must be inert until promotion")
example = yaml.safe_load(EXAMPLE_VALUES.read_text())
if example.get("workload", {}).get("enabled") is not True:
    fail("the release example must exercise the workload gate")
if not str(example["image"]["digest"]).startswith("sha256:"):
    fail("the release-values example must document an immutable sha256 digest")
template = RELEASE_TEMPLATE.read_text()
for placeholder in ("${ACR_LOGIN_SERVER}", "${ACR_APPLICATION_REPOSITORY}", "${IMAGE_DIGEST}"):
    if placeholder not in template:
        fail(f"release template is missing {placeholder}")

workflow_text = WORKFLOW.read_text()
workflow = yaml.safe_load(workflow_text)
jobs = workflow.get("jobs", {})
for job in ("build-push", "sign-attest", "verify", "lock-verified-image", "promote"):
    if job not in jobs:
        fail(f"Azure deploy workflow is missing the {job} job")
if "deploy" in jobs:
    fail("Azure deploy workflow must not bypass reviewed Argo promotion with direct Helm deployment")
if "values.release.yaml" not in workflow_text:
    fail("Azure promotion must produce values.release.yaml")
if "helm upgrade --install" in workflow_text or "az login" in workflow_text:
    fail("Azure promotion must not directly mutate the cluster or perform Azure login")
if jobs["promote"].get("permissions") != {"contents": "write"}:
    fail("only the promotion job may have the narrow contents: write exception")
if "id-token" in jobs["promote"].get("permissions", {}):
    fail("Azure promotion must not have OIDC authority")
if jobs["promote"].get("if") != "github.ref == 'refs/heads/main'":
    fail("Azure promotion must be restricted to the trusted main ref")
if not re.search(r"\^sha256:\[0-9a-f\]\{64\}\$", workflow_text):
    fail("Azure promotion must validate the exact sha256 digest shape")
if "git push origin \"HEAD:refs/heads/main\"" not in workflow_text:
    fail("Azure promotion must push the verified values file to main")
if "k8s/azure/**" in workflow_text:
    fail("broad Azure chart path filters would recurse on values.release.yaml")
if "git add -- \"$release_file\"" not in workflow_text:
    fail("Azure promotion must stage only the release values file")

print("All Azure GitOps contract checks passed.")
