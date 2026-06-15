#!/usr/bin/env python3
"""
Regression test for Kyverno ClusterPolicy Rule 3 (verify-provenance-attestation).

Evaluates the *actual* JMESPath conditions shipped in
policy/kyverno/block-unsigned-images.yaml against a real captured SLSA
provenance predicate (see fixtures/provenance-predicate.json, matching
the exact shape sign-attest.yml generates for a real signed build).

This exists because this exact rule shipped broken twice in this repo:
once with an incorrect `predicate.` prefix (Kyverno scopes JMESPath
directly to the predicate body -- there is no top-level `predicate` key
to descend into), and once with the entryPoint condition checking
`deploy.yml` instead of the workflow that actually produces the
provenance (`sign-attest.yml`). Neither bug was caught by human review
of the YAML -- both were only found by reading the policy against a
real predicate. This script automates that check so it can't regress
silently again.

Run directly: python3 policy/tests/test_jmespath_conditions.py
"""
import json
import sys
from pathlib import Path

import jmespath
import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
POLICY_FILE = REPO_ROOT / "policy" / "kyverno" / "block-unsigned-images.yaml"
FIXTURE_FILE = Path(__file__).resolve().parent / "fixtures" / "provenance-predicate.json"

RULE_NAME = "verify-provenance-attestation"


def load_conditions():
    docs = list(yaml.safe_load_all(POLICY_FILE.read_text()))
    policy = docs[0]
    for rule in policy["spec"]["rules"]:
        if rule["name"] != RULE_NAME:
            continue
        for verify_image in rule["verifyImages"]:
            for attestation in verify_image.get("attestations", []):
                for cond_block in attestation.get("conditions", []):
                    yield from cond_block["all"]


def strip_kyverno_braces(expr: str) -> str:
    # Kyverno JMESPath keys are wrapped like "{{ invocation.foo }}" --
    # strip the braces to get a plain JMESPath expression.
    expr = expr.strip()
    if expr.startswith("{{"):
        expr = expr[2:]
    if expr.endswith("}}"):
        expr = expr[:-2]
    return expr.strip()


def main() -> int:
    predicate = json.loads(FIXTURE_FILE.read_text())
    conditions = list(load_conditions())

    if not conditions:
        print(f"FAIL: no conditions found for rule '{RULE_NAME}' -- "
              f"has the policy structure changed? Update this test's "
              f"RULE_NAME/parsing to match.")
        return 1

    failures = 0
    for cond in conditions:
        raw_key = cond["key"]
        expected = cond["value"]
        operator = cond.get("operator", "Equals")
        expr = strip_kyverno_braces(raw_key)

        actual = jmespath.search(expr, predicate)

        if operator == "Equals":
            ok = actual == expected
        elif operator == "NotEquals":
            ok = actual != expected
        else:
            print(f"SKIP: unsupported operator '{operator}' for {expr!r} "
                  f"-- extend this test to cover it")
            continue

        status = "OK  " if ok else "FAIL"
        print(f"{status}: {expr!r} -> {actual!r}  (expected {operator} {expected!r})")

        if not ok:
            failures += 1

    if failures:
        print(f"\n{failures} condition(s) would not match a real provenance predicate.")
        print("This is exactly the bug class that shipped twice already -- fix the")
        print("policy YAML, not this fixture, unless the predicate shape itself changed.")
        return 1

    print("\nAll Rule 3 conditions match the real provenance predicate shape.")
    return 0


if __name__ == "__main__":
    sys.exit(main())