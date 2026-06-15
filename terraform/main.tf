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

  rules {
    deletion         = true
    non_fast_forward = true

    pull_request {
      required_approving_review_count = 1
      require_code_owner_review       = true
      dismiss_stale_reviews_on_push   = true
      require_last_push_approval      = true
    }

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
      strict_required_status_checks_policy = true
    }
}
}