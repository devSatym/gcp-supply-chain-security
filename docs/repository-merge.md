# Repository merge record

## Current canonical monorepo

This repository is the canonical project repository:

- `https://github.com/devSatym/gcp-supply-chain-security.git`

It combines application/security and infrastructure/runtime-security components in one monorepo. The application/security layer remains at the repository root; the imported infrastructure component remains below `infrastructure/`.

## Upstream attribution

The two component areas were originally sourced from:

- Application/security component: [`musaumakau/supply-chain-security`](https://github.com/musaumakau/supply-chain-security)
- Infrastructure/runtime-security component: [`musaumakau/gcp-infrastructure-modules`](https://github.com/musaumakau/gcp-infrastructure-modules)

Those repositories are retained as attribution and provenance context. This document does not claim that their current upstream commit IDs are identical to the current canonical monorepo commit IDs.

## Canonical merge topology

The current history-combining merge is `6717e4491d3e8a2d0b6fd6044a673041f30d040c`.

```text
Application-side merge parent:
cc1fa07a617320a8efdf31bb9aa67927128bd3a0

Infrastructure-side merge parent:
c88320f1b2ac1995aa1d75f481e1f69d7063c2ba

History-combining merge:
6717e4491d3e8a2d0b6fd6044a673041f30d040c

Post-merge documentation commit:
b90bcc75dae48231a04e2efcedc51eb70dfac89c
```

The merge has two parents: the application-side parent is first and the infrastructure-side parent is second. Both are ancestors of the current `main` HEAD.

## Verification performed

On 2026-08-23, the following local checks passed:

```bash
git cat-file -t cc1fa07a617320a8efdf31bb9aa67927128bd3a0
git cat-file -t c88320f1b2ac1995aa1d75f481e1f69d7063c2ba
git cat-file -t 6717e4491d3e8a2d0b6fd6044a673041f30d040c
git cat-file -t b90bcc75dae48231a04e2efcedc51eb70dfac89c

git merge-base --is-ancestor cc1fa07a617320a8efdf31bb9aa67927128bd3a0 HEAD
git merge-base --is-ancestor c88320f1b2ac1995aa1d75f481e1f69d7063c2ba HEAD
```

All four objects are commits. The merge has exactly the two parents listed above, and both ancestry checks exit successfully.

## Workflow implication

Original infrastructure workflows are preserved unchanged at `infrastructure/.github/`. GitHub Actions does not execute workflows from that nested path. Any workflow needed for the monorepo is created as a root workflow under `.github/workflows/`, with monorepo-safe paths and working directories; the retained nested workflow remains provenance material.

## History safety

Implementation begins from the current canonical `main` history. No history repair, upstream-history merge, rebase, reset, replace, filter, or force-push is part of this implementation work.
