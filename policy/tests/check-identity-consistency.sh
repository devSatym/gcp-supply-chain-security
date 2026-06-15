#!/usr/bin/env bash
# Regression guard for certificate-identity drift.
#
# Only .github/workflows/sign-attest.yml actually runs `cosign sign` /
# `cosign attest` in this repo. Every consumer of that identity --
# Kyverno's ClusterPolicy subjects, the Gatekeeper/Ratify Verifier CRD,
# and verify.yml's CERT_IDENTITY -- must reference exactly that
# workflow file on refs/heads/main, or verification fails with
# "none of the expected identities matched".
#
# This exact class of bug has shipped twice in this repo already:
#   1. Kyverno Rule 3 checked "deploy.yml" instead of "sign-attest.yml"
#   2. verify.yml checked "verify.yml.yml", then later "verify.yml"
#      (itself) instead of "sign-attest.yml"
# Neither was a Kyverno-specific bug, so a Kyverno-only test suite
# would not have caught #2. This script checks every file that embeds
# an identity string, regardless of which tool consumes it.

set -euo pipefail

CANONICAL_SUFFIX="sign-attest.yml@refs/heads/main"
CANONICAL_ENTRYPOINT="\.github/workflows/sign-attest\.yml"
FAIL=0

# --- Check full "<...>/<workflow>.yml[.yml]@refs/heads/main" identity strings ---
check_full_identity() {
  local file="$1"
  local matches
  matches=$(grep -oE '\.github/workflows/[a-zA-Z0-9_-]+\.yml(\.yml)?@refs/heads/main' "$file" || true)

  if [ -z "$matches" ]; then
    echo "SKIP  (no full identity string found): $file"
    return
  fi

  while IFS= read -r m; do
    if [[ "$m" == *"$CANONICAL_SUFFIX" ]]; then
      echo "OK    $file -> $m"
    else
      echo "FAIL  $file -> $m  (expected suffix: $CANONICAL_SUFFIX)"
      FAIL=1
    fi
  done <<< "$matches"
}

# --- Check bare entryPoint condition values, e.g. Kyverno Rule 3 ---
check_entrypoint_value() {
  local file="$1"
  local matches
  matches=$(grep -oE '"\.github/workflows/[a-zA-Z0-9_-]+\.yml(\.yml)?"' "$file" || true)

  if [ -z "$matches" ]; then
    echo "SKIP  (no bare entryPoint value found): $file"
    return
  fi

  while IFS= read -r m; do
    if [[ "$m" =~ $CANONICAL_ENTRYPOINT ]]; then
      echo "OK    $file -> $m"
    else
      echo "FAIL  $file -> $m  (expected: \".github/workflows/sign-attest.yml\")"
      FAIL=1
    fi
  done <<< "$matches"
}

echo "--- Checking full identity references (subject / certificateIdentity / CERT_IDENTITY) ---"
check_full_identity policy/kyverno/block-unsigned-images.yaml
check_full_identity policy/gatekeeper/verifier-cosign.yaml
check_full_identity .github/workflows/verify.yml

echo ""
echo "--- Checking bare entryPoint condition values ---"
check_entrypoint_value policy/kyverno/block-unsigned-images.yaml

echo ""
if [ "$FAIL" -ne 0 ]; then
  echo "One or more files reference a certificate identity other than sign-attest.yml."
  echo "Only sign-attest.yml actually signs/attests images -- every verifier must"
  echo "check against that exact workflow, or verification will always fail."
  exit 1
fi

echo "All certificate identity references are consistent."
