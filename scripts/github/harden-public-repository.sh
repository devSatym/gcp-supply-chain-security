#!/usr/bin/env bash
set -Eeuo pipefail

# One-time GitHub control-plane hardening for the public Azure repository.
# This script never changes repository visibility and never reads or writes a
# cloud credential. It requires an owner-authorized `gh` session.

REPOSITORY="devSatym/gcp-supply-chain-security"
ACTIONS_INTEGRATION_ID=15368

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

command -v gh >/dev/null 2>&1 || die "GitHub CLI is required"

visibility="$(gh api "repos/${REPOSITORY}" --jq .visibility)"
test "$visibility" = public || die "refusing to modify repository visibility; expected public, got ${visibility}"

# GitHub Advanced Security, secret scanning, and push protection are free for
# public repositories. This does not make the repository private or change
# Actions permissions.
jq -n '{
  security_and_analysis: {
    advanced_security: {status: "enabled"},
    secret_scanning: {status: "enabled"},
    secret_scanning_push_protection: {status: "enabled"}
  }
}' | gh api --method PATCH "repos/${REPOSITORY}" --input - >/dev/null

ruleset_payload="$(jq -n --argjson integration "$ACTIONS_INTEGRATION_ID" '{
  name: "azure-main-protection",
  target: "branch",
  enforcement: "active",
  conditions: {ref_name: {include: ["~DEFAULT_BRANCH"], exclude: []}},
  bypass_actors: [
    {actor_id: $integration, actor_type: "Integration", bypass_mode: "always"}
  ],
  rules: [
    {type: "deletion"},
    {type: "non_fast_forward"},
    {type: "pull_request", parameters: {
      dismiss_stale_reviews_on_push: true,
      require_code_owner_review: false,
      require_last_push_approval: false,
      required_approving_review_count: 0,
      required_review_thread_resolution: true
    }},
    {type: "required_status_checks", parameters: {
      strict_required_status_checks_policy: true,
      do_not_enforce_on_create: false,
      required_status_checks: [
        {context: "Secret scanning (full history)", integration_id: $integration},
        {context: "CodeQL (Python)", integration_id: $integration},
        {context: "SAST, dependency, container, IaC, and workflow policy", integration_id: $integration}
      ]
    }}
  ]
}')"

ruleset_id="$(gh api "repos/${REPOSITORY}/rulesets" --paginate --jq '.[] | select(.name == "azure-main-protection") | .id' | head -n 1)"
if [[ -n "$ruleset_id" ]]; then
  printf '%s' "$ruleset_payload" | gh api --method PUT "repos/${REPOSITORY}/rulesets/${ruleset_id}" --input - >/dev/null
else
  printf '%s' "$ruleset_payload" | gh api --method POST "repos/${REPOSITORY}/rulesets" --input - >/dev/null
fi

printf 'Public repository controls are enabled for %s.\n' "$REPOSITORY"
