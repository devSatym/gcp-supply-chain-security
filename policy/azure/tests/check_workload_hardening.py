#!/usr/bin/env python3
"""Offline assertions for the private Azure application workload boundary."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import yaml


REPO = Path(__file__).resolve().parents[3]
CHART = REPO / "k8s/azure/supply-chain-demo"
RELEASE_VALUES = CHART / "values.release.yaml.example"
APPLICATION = REPO / "argocd/supply-chain-azure-demo-app.yaml"
RESTRICTED_POLICY = REPO / "policy/azure/kyverno/restricted-workloads.yaml"


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


rendered = subprocess.check_output(
    [
        "helm",
        "template",
        "supply-chain-demo",
        str(CHART),
        "--namespace",
        "supply-chain",
        "--values",
        str(RELEASE_VALUES),
    ],
    text=True,
)
documents = [doc for doc in yaml.safe_load_all(rendered) if doc]
by_kind = {doc["kind"]: doc for doc in documents}

namespace = by_kind.get("Namespace")
if namespace is None:
    fail("chart must manage the application Namespace")
labels = namespace.get("metadata", {}).get("labels", {})
for mode in ("enforce", "audit", "warn"):
    if labels.get(f"pod-security.kubernetes.io/{mode}") != "restricted":
        fail(f"Namespace must set Pod Security Admission {mode}=restricted")

service_account = by_kind.get("ServiceAccount")
if service_account is None or service_account.get("automountServiceAccountToken") is not False:
    fail("application ServiceAccount must disable token automount")

deployment = by_kind.get("Deployment")
if deployment is None:
    fail("release chart must render a Deployment")
podspec = deployment["spec"]["template"]["spec"]
if podspec.get("automountServiceAccountToken") is not False:
    fail("Pod must disable token automount")
if podspec.get("serviceAccountName") != "supply-chain-demo":
    fail("Pod must use the dedicated application ServiceAccount")
pod_security = podspec.get("securityContext", {})
if pod_security.get("runAsNonRoot") is not True or pod_security.get("seccompProfile", {}).get("type") != "RuntimeDefault":
    fail("Pod must be non-root with RuntimeDefault seccomp")
container = podspec["containers"][0]
security = container.get("securityContext", {})
if not (
    security.get("allowPrivilegeEscalation") is False
    and security.get("readOnlyRootFilesystem") is True
    and security.get("runAsNonRoot") is True
    and security.get("capabilities", {}).get("drop") == ["ALL"]
):
    fail("container must use the restricted security context")
if "@sha256:" not in container.get("image", ""):
    fail("release workload image must be digest pinned")

network_policy = by_kind.get("NetworkPolicy")
if network_policy is None:
    fail("chart must render a default-deny NetworkPolicy")
spec = network_policy["spec"]
if set(spec.get("policyTypes", [])) != {"Ingress", "Egress"}:
    fail("NetworkPolicy must deny ingress and egress by default")
if not spec.get("egress"):
    fail("NetworkPolicy must explicitly allow only DNS egress")
ports = {port["port"] for port in spec["egress"][0].get("ports", [])}
if ports != {53}:
    fail("NetworkPolicy egress must be limited to DNS port 53")

pdb = by_kind.get("PodDisruptionBudget")
if pdb is None or pdb.get("spec", {}).get("minAvailable") != 1:
    fail("release workload requires a PodDisruptionBudget with minAvailable=1")

application = yaml.safe_load(APPLICATION.read_text())
if application["spec"]["destination"].get("namespace") != "supply-chain":
    fail("Argo CD Application must target supply-chain namespace")
if "CreateNamespace=true" not in application["spec"].get("syncPolicy", {}).get("syncOptions", []):
    fail("Argo CD must create the namespace before reconciliation")

policy = yaml.safe_load(RESTRICTED_POLICY.read_text())
if policy.get("spec", {}).get("validationFailureAction") != "Enforce":
    fail("restricted-workloads policy must enforce")
rule = policy["spec"]["rules"][0]
if rule["match"]["any"][0]["resources"].get("namespaces") != ["supply-chain"]:
    fail("restricted-workloads policy must be scoped only to supply-chain")

print("Azure workload hardening contract checks passed.")
