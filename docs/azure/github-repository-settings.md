# GitHub repository settings review

Reviewed 2026-10-04 against the current worktree and authenticated GitHub API.
Azure is authoritative; the repository name remains part of signing,
provenance, and OIDC trust contracts.

## Applied GitHub settings

| Setting | Result |
| --- | --- |
| About description | Azure reference implementation with private AKS, OIDC, signed images, GitOps, admission, and runtime controls |
| Topics | Azure, AKS, DevSecOps, Terraform, GitHub Actions, Kubernetes, GitOps, Argo CD, Kyverno, Cosign, Sigstore, SBOM, SLSA, Falco, FastAPI, container security, OIDC, software supply-chain security |
| Homepage | Current Azure documentation directory |
| Default branch / visibility | Existing public `main` retained |
| Wiki | Disabled; the repository documentation is the maintained source |
| Merge housekeeping | Automatic branch deletion after merge and update-branch suggestions enabled |
| Dependency alerts | Enabled; Renovate's existing vulnerability-alert configuration retained |
| Private vulnerability reporting | Enabled; linked by the security policy and issue routing |
| Secret scanning / push protection | Existing enabled settings retained |
| Actions policy | External action references must use a full commit SHA |
| Default workflow token | Existing read-only default retained; PR approval permission remains disabled |
| Trusted branch history | Active ruleset rejects deletion and non-fast-forward updates to `main` |
| Tag history | Active ruleset rejects updates/deletion of `final-gcp-commit` and `v*` tags |
| Triage labels | Added labels used by Renovate and by Azure/security/release work |

Dependabot automatic security PRs remain disabled because Renovate already
manages vulnerability PRs. Dependency alerts are enabled. Existing advanced
CodeQL analysis is retained; duplicate default CodeQL setup was not enabled.
Projects and Discussions settings were not changed.

## Community and presentation files

- README files retain their original contents at the owner's request.
- `CONTRIBUTING.md` and `SECURITY.md`: contribution checks and private reporting.
- `.github/ISSUE_TEMPLATE/`: bug/feature forms and private-security routing.
- `.github/PULL_REQUEST_TEMPLATE.md`: scope, validation, and live evidence.
- `.github/release.yml` and `CHANGELOG.md`: categorized release documentation.

Repository-wide Apache 2.0 licensing is pending confirmation of rights to the
imported upstream code. Neither credited upstream repository currently exposes
a detected license through GitHub. Attribution alone does not resolve that
question; no license badge or blanket license grant is published while it is
unresolved.

## Decisions and remaining verification

Mandatory PR approval or global required-check gates were not added: the
current release workflow directly pushes a verified digest to `main`, and
Azure static/image checks use path filters. Before tightening these gates,
design an authenticated promotion path compatible with the rules and ensure
required checks run for every affected PR. The history rules currently allow
ordinary fast-forward promotion pushes.

The preview release should identify its exact source commit and remain a
prerelease until current Azure evidence establishes the complete delivery
path. Keep the historical GCP tag unchanged. Signing a container and publishing
a GitHub source release are separate operations; source release tags do not
receive Azure signing authority.

At review time, the latest observed Azure static run succeeded; the latest
Azure Deploy run was cancelled and the preceding build attempt failed. The
latest scheduled security run failed in the full-history secret gate, while
the latest main push security run succeeded. These are per-run observations,
not an assertion of a currently healthy deployment. Inspect GitHub's run
pages for current results.

Local policy and chart checks pass. Live Azure promotion, private connectivity,
admission enforcement, DAST, drift behavior, and alert delivery remain separate
validation. In particular, review Git authentication in the promotion job:
checkout disables persisted credentials and the shown push has no explicit
authenticated remote setup. No cloud deployment was performed by this review.

Manual dispatch of the drift and DAST workflows lacks an explicit main-ref
guard for private-runner scheduling. The current Azure OIDC trust is bound to
main and PR events do not select these workflows, but that does not establish
main-only scheduling for every manually dispatched workflow. Review the
dispatch guards before claiming that stronger execution boundary.

## Read-only verification

```bash
gh repo view devSatym/gcp-supply-chain-security \
  --json description,homepageUrl,repositoryTopics,licenseInfo,latestRelease
gh api repos/devSatym/gcp-supply-chain-security/rulesets
gh api repos/devSatym/gcp-supply-chain-security/actions/permissions
gh api repos/devSatym/gcp-supply-chain-security/actions/permissions/workflow
gh api repos/devSatym/gcp-supply-chain-security/private-vulnerability-reporting
gh api repos/devSatym/gcp-supply-chain-security/community/profile
gh release list --repo devSatym/gcp-supply-chain-security
```

API semantics: [repository settings](https://docs.github.com/en/rest/repos/repos),
[rulesets](https://docs.github.com/en/rest/repos/rules), and
[Actions permissions](https://docs.github.com/en/rest/actions/permissions).
