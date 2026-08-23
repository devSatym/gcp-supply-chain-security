# environments/prod/falco.tf
#
# Falco DaemonSet + Falcosidekick against prod-cluster, publishing to
# the optional Pub/Sub topic wired up in falco-alerting.tf.

module "falco" {
  source = "../../falco"

  project_id              = var.project_id
  cluster_name            = var.cluster_name
  region                  = var.region
  alert_pubsub_topic_id   = var.enable_runtime_alerting ? module.falco_alerting[0].pubsub_topic_id : null
  falcosidekick_gsa_email = var.enable_runtime_alerting ? google_service_account.falcosidekick[0].email : null
  falco_helm_version      = "9.1.0"

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
        (k8s.ns.name = "external-dns" and proc.name = "external-dns")
  EOT

  depends_on = [
    module.gke,
    google_service_account_iam_member.falcosidekick_workload_identity,
  ]
}
