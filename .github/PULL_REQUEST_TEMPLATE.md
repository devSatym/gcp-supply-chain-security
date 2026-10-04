## Problem and change

Describe the problem and resulting behavior. Link the related issue, if any.

## Security and operational impact

Describe changes to trust boundaries, cloud permissions, artifact verification,
private connectivity, or costs. Write "None" if none apply.

## Validation performed

List the commands or workflow runs you actually executed and their results.
For checks not run, give the reason.

## Live Azure evidence

State what was observed in a live environment, or write "Not performed".
List any live validation still required. Local tests and chart renders alone
do not establish deployment health, admission enforcement, or alert delivery.

## Review checklist

- [ ] The change is focused and documents affected behavior.
- [ ] Relevant local checks are recorded above.
- [ ] OIDC-only Azure authentication, trusted-main execution, private AKS, and digest-pinned deployment are preserved, or an explicitly approved architecture change is explained.
- [ ] No credentials, kubeconfigs, Terraform state, webhook URLs, provider caches, or unsanitized evidence are included.
