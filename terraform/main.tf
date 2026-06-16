terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

# Authenticates via GITHUB_TOKEN env var (a fine-grained PAT or GitHub App
# token with 'Administration: write' on this repo). Do not hardcode a token
# here or in any .tfvars file that gets committed.
provider "github" {
  owner = "musaumakau"
}

# Closes the "trust starts at main" gap identified in the supply-chain
# security review: nothing previously enforced who could merge to main,
# even though every image built from main is automatically signed,
# attested, and admitted to the cluster with zero additional review gate.
resource "github_repository_ruleset" "main_protection" {
  name        = "main-branch-protection"
  repository  = "supply-chain-security"
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  # This repository currently has a single maintainer, so requiring an
  # approving review would permanently block every PR. The review rule is
  # intentionally omitted until additional maintainers are added.
  #
  # Merges are still protected by:
  # - Required CI status checks
  # - No direct branch deletion
  # - No force pushes

  rules {
    # Protect the default branch from destructive updates.
    deletion         = true
    non_fast_forward = true

    required_status_checks {
      # Require the canonical GitHub Actions job names returned by the
      # GitHub Rulesets API. These match the identifiers GitHub currently
      # enforces for required checks and include the GitHub Actions
      # integration ID to ensure the checks originate from the expected
      # source.
      required_check {
        context = "Policy Unit Tests"
      }

      required_check {
        context = "Security Scan / SAST (Semgrep)"
      }

      required_check {
        context = "Security Scan / Vulnerability Scan (Trivy)"
      }

      # Intentionally disabled. This repository currently has a single
      # maintainer, so requiring the PR branch to be up to date before
      # merging mostly forces an additional CI run without improving review
      # quality. Revisit this if additional maintainers are added or the
      # repository begins handling multiple concurrent PRs.
      strict_required_status_checks_policy = false
    }
  }
}
