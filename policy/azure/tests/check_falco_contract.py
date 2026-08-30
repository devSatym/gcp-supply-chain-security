#!/usr/bin/env python3
"""Check the Azure Falco parity rule without a cluster or Helm install."""

import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("pyyaml is required: python3 -m pip install pyyaml", file=sys.stderr)
    sys.exit(2)


REPO = Path(__file__).resolve().parents[3]
RULES = REPO / "infrastructure/azure/falco/custom-rules.yaml"
FALCO_MAIN = REPO / "infrastructure/azure/falco/main.tf"
PROD_MAIN = REPO / "infrastructure/azure/environments/prod/main.tf"


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


rules = yaml.safe_load(RULES.read_text())
if not isinstance(rules, list):
    fail("custom-rules.yaml must contain a YAML list")

rule = next((item for item in rules if item.get("rule") == "Shell Spawned In Signed Workload Pod"), None)
if rule is None:
    fail("the GCP active shell-spawn rule is missing from the Azure custom rules")

condition = rule.get("condition", "")
if "spawned_process" not in condition or "container" not in condition or "shell_binaries" not in condition:
    fail("the shell-spawn rule must match spawned shell processes in containers")
for namespace in ("kube-system", "falco-system", "kyverno", "argocd"):
    if namespace not in condition:
        fail(f"the shell-spawn rule must exclude the {namespace} control-plane namespace")
if "external-dns" in RULES.read_text().lower():
    fail("the Azure parity rule must not reintroduce the GCP-only ExternalDNS suppression")
if rule.get("priority") != "CRITICAL":
    fail("the shell-spawn rule must remain CRITICAL")
if set(rule.get("tags", [])) != {"supply-chain", "shell"}:
    fail("the shell-spawn rule tags drifted")

falco_text = FALCO_MAIN.read_text()
if 'rule_matching = "all"' not in falco_text or "customRules" not in falco_text:
    fail("Falco must load all custom rules through the Helm values")
prod_text = PROD_MAIN.read_text()
if "custom_rules_yaml" not in prod_text or "custom-rules.yaml" not in prod_text:
    fail("the production root must pass the reviewed Azure custom rules file")

print("All Azure Falco parity contract checks passed.")
