# Personal live validation

Captured 2026-08-23 against project `valiant-house-502004-k2` in
`europe-west1`. This file records the live implementation evidence; the older
`docs/evidence/` directory remains historical upstream material.

## History gate

```text
merge: 6717e4491d3e8a2d0b6fd6044a673041f30d040c
parent 1: cc1fa07a617320a8efdf31bb9aa67927128bd3a0
parent 2: c88320f1b2ac1995aa1d75f481e1f69d7063c2ba
two-parent merge: PASS
parent 1 ancestor of HEAD: PASS
parent 2 ancestor of HEAD: PASS
history repair: NO
history rewrite: NO
```

## CI and artifact

GitHub Actions run `32630716371` for commit `9bf574c` completed successfully:
Build/Push, SBOM/VEX, Sign and Attest, and Verify. The deployed primary GAR
image is:

```text
europe-west1-docker.pkg.dev/valiant-house-502004-k2/supply-chain-security/supply-chain-demo@sha256:32a90d832fdf76794fa5477e42e1fdcec28c9eb6e0deee48ad466d1f7d9fc563
```

The immutable primary repository has the matching digest. Legacy Cosign
metadata is in the separate repository:

```text
europe-west1-docker.pkg.dev/valiant-house-502004-k2/supply-chain-security-attestations/supply-chain-demo
```

The CI verification log confirmed the canonical keyless subject, GitHub OIDC
issuer, Rekor verification, SPDX JSON, SLSA v0.2 provenance, GitHub runner
builder, `sign-attest.yml` entrypoint, and canonical monorepo source URI.

## Cluster and GitOps

```text
Kyverno policy: Ready / Enforce
Argo Application: Synced / Healthy
Application: 2/2 replicas available
Falco: 1/1 DaemonSet pod on the autoscaled live node
Terraform final plan: No changes
```

The application `/health` response was `{"status":"healthy","service":"supply-chain-demo"}`;
`/info` returned the expected service/version metadata.

## Admission results

- Trusted Helm Deployment using the signed digest passed Kyverno server dry-run
  and ran live through Argo CD.
- Real GAR tag `unsigned-test` (digest
  `sha256:18549c45e5d1d87804372cb8082cefbee1019b9c592d816d14817cc12472ca17`)
  was denied with `no signatures found` and no matching attestations.
- Both mixed-container and unsigned-initContainer fixtures were denied.
- A temporary test policy with an incorrect keyless subject and incorrect SLSA
  source URI denied the known signed digest; the temporary policy was deleted
  immediately after the test.

## Runtime result

Falco loaded `/etc/falco/rules.d/custom-rules.yaml` with schema validation
passing. A controlled `kubectl exec` shell emitted:

```text
Critical Unexpected shell spawned in hardened pod
rule=Shell Spawned In Signed Workload Pod
namespace=default
command=sh -c id
```

No Discord alert was captured because the alerting path is disabled until a real
webhook is supplied.
