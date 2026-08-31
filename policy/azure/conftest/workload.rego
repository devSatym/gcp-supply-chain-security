package main

deny[msg] {
  input.kind == "Service"
  input.spec.type == "LoadBalancer"
  msg := "Azure application Service must never expose a public LoadBalancer"
}

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not contains(container.image, "@sha256:")
  msg := sprintf("container %q must use a digest-pinned image", [container.name])
}

deny[msg] {
  input.kind == "Deployment"
  input.spec.template.spec.automountServiceAccountToken != false
  msg := "application Pod must disable ServiceAccount token automount"
}

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  container.securityContext.allowPrivilegeEscalation != false
  msg := sprintf("container %q must disallow privilege escalation", [container.name])
}

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  container.securityContext.readOnlyRootFilesystem != true
  msg := sprintf("container %q must use a read-only root filesystem", [container.name])
}

deny[msg] {
  input.kind == "Namespace"
  input.metadata.name == "supply-chain"
  input.metadata.labels["pod-security.kubernetes.io/enforce"] != "restricted"
  msg := "supply-chain Namespace must enforce the restricted Pod Security Standard"
}

deny[msg] {
  input.kind == "NetworkPolicy"
  not has_policy_type(input.spec.policyTypes, "Ingress")
  msg := "application NetworkPolicy must include ingress isolation"
}

deny[msg] {
  input.kind == "NetworkPolicy"
  not has_policy_type(input.spec.policyTypes, "Egress")
  msg := "application NetworkPolicy must include egress isolation"
}

has_policy_type(policy_types, expected) {
  policy_types[_] == expected
}
