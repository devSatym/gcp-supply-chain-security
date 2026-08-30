#!/usr/bin/env python3
"""Check the reviewed Azure Argo CD and digest-promotion contract."""

import sys
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
if app["spec"].get("syncPolicy") != {}:
    fail("Azure Argo automation must remain disabled until a concrete release file is reviewed")

base = yaml.safe_load(BASE_VALUES.read_text())
if base["image"]["repository"] != "${ACR_LOGIN_SERVER}/${ACR_APPLICATION_REPOSITORY}":
    fail("the base Azure chart must remain placeholder-safe")
if base["image"]["digest"] != "${IMAGE_DIGEST}":
    fail("the base Azure chart must remain digest-shaped")
example = yaml.safe_load(EXAMPLE_VALUES.read_text())
if not str(example["image"]["digest"]).startswith("sha256:"):
    fail("the release-values example must document an immutable sha256 digest")

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
if "helm upgrade --install" in workflow_text or "contents: write" in workflow_text:
    fail("Azure promotion must not directly mutate the cluster or repository")
if jobs["promote"].get("permissions", {}).get("contents") != "read":
    fail("Azure promotion must have read-only repository permissions")

print("All Azure GitOps contract checks passed.")
