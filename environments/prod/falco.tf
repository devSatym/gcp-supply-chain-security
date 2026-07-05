# environments/prod/falco.tf
#
# Falco DaemonSet + Falcosidekick against prod-cluster, publishing to
# the Pub/Sub topic wired up in falco-alerting.tf.

module "falco" {
  source = "../../falco"

  project_id                        = var.project_id
  cluster_name                      = var.cluster_name
  region                            = var.region
  alert_pubsub_topic_id             = module.falco_alerting.pubsub_topic_id
  falcosidekick_gsa_email           = google_service_account.falcosidekick.email
  falco_helm_version                = "9.1.0"
  falcosidekick_gcp_credentials_b64 = google_service_account_key.falcosidekick.private_key

  # Tuned against a cluster where every workload is signed (Cosign) and
  # scanned (Trivy/Semgrep) before admission - so behavior that would be
  # routine on a general-purpose cluster is a strong signal here.
  custom_rules_yaml = <<-EOT
    - rule: Shell Spawned In Signed Workload Pod
      desc: >
        No pod in this cluster should ever exec a shell - every image is
        built, signed, and admitted through the supply-chain-security
        pipeline with no interactive tooling included by design.
      condition: >
        spawned_process and container and
        proc.name in (shell_binaries) and
        not k8s.ns.name in (kube-system, falco-system)
      output: >
        Unexpected shell spawned in hardened pod
        (user=%user.name pod=%k8s.pod.name ns=%k8s.ns.name
        container=%container.name image=%container.image.repository
        cmdline=%proc.cmdline)
      priority: CRITICAL
      tags: [supply-chain, shell]
    - macro: user_known_contact_k8s_api_server_activities
      condition: >
        (k8s.ns.name = "external-dns" and proc.name = "external-dns") or
        (k8s.ns.name = "gatekeeper-system" and proc.name = "manager")
  EOT
}