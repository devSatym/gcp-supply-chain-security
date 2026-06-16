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

  # This repo currently has a single maintainer, so a "review from someone
  # else" requirement has no one who can ever satisfy it -- it would
  # permanently block every PR (confirmed: it did, on PR #65, requiring a
  # manual admin bypass to merge). Rather than keep a rule that only ever
  # gets bypassed, the review requirement is intentionally omitted here.
  #
  # What still fully gates every merge to main, no exceptions, for anyone
  # including the repo owner: all required status checks below (Semgrep,
  # Trivy, policy unit tests), no direct pushes, no force-pushes, no branch
  # deletion. If a second maintainer/collaborator is ever added, add a
  # `pull_request { required_approving_review_count = 1 ... }` block back
  # into `rules` below to reinstate cross-review.

  rules {
    # No one can push directly to main, or force-push/delete it.
    deletion         = true
    non_fast_forward = true

    required_status_checks {
      required_check {
        context = "PR Check / Security Scan / SAST (Semgrep) (pull_request)"
      }
      required_check {
        context = "PR Check / Security Scan / Vulnerability Scan (Trivy) (pull_request)"
      }
      required_check {
        context = "PR Check / Policy Unit Tests (pull_request)"
      }
      
# Intentionally disabled. This repository currently has a single maintainer,
# so requiring every PR branch to be up to date before merging primarily
# forces an additional CI run without providing independent review value.
# Re-enable if the repository gains additional maintainers or experiences
# frequent concurrent PRs, where validating against the latest default
# branch before merge becomes more valuable.
strict_required_status_checks_policy = false
  }
}
}