# modules/falco/main.tf
#
# Deploys Falco (eBPF runtime detection) + Falcosidekick (alert routing)
# onto an existing private, VPC-native GKE cluster. Falco itself needs
# no cloud credentials. Falcosidekick publishes through a GKE Workload
# Identity-bound Kubernetes ServiceAccount when Pub/Sub alerting is enabled;
# no JSON service-account key is created or passed to Helm.
#
# IMPORTANT: rule_matching must be set to "all" (Falco's default is
# "first" as of 0.36.0+). With the default, Falco stops evaluating
# further rules against an event once ANY rule matches - so a broad
# built-in rule (e.g. "Terminal shell in container") silently prevents
# more specific custom rules from ever firing on the same event, with
# no error or warning. Confirmed via live testing: custom rules loaded
# and enabled correctly (per `falco -L`) but never fired until this was
# set. See: https://github.com/falcosecurity/falco/issues/2891

resource "kubernetes_namespace" "falco" {
  metadata {
    name   = var.namespace
    labels = var.labels
  }
}

resource "helm_release" "falco" {
  name       = "falco"
  repository = "https://falcosecurity.github.io/charts"
  chart      = "falco"
  version    = var.falco_helm_version
  namespace  = kubernetes_namespace.falco.metadata[0].name

  # GKE Autopilot and hardened node images generally don't allow the
  # legacy kmod driver to build in-cluster; modern_ebpf needs no kernel
  # headers and works across COS and Ubuntu node pools without extra config.
  values = [
    yamlencode({
      driver = {
        kind = var.falco_driver
      }

      falco = {
        rule_matching = "all"
      }

      collectors = {
        kubernetes = {
          enabled = true
        }
      }

      resources = var.resources

      falcosidekick = {
        enabled      = var.enable_falcosidekick
        replicaCount = 2

        config = {
          debug = false

          gcp = var.alert_pubsub_topic_id != null ? {
            pubsub = {
              projectid = var.project_id
              topic     = split("/", var.alert_pubsub_topic_id)[3]
            }
          } : {}
        }
      }

      customRules = var.custom_rules_yaml != "" ? {
        "custom-rules.yaml" = var.custom_rules_yaml
      } : {}

      tolerations = [
        {
          effect   = "NoSchedule"
          operator = "Exists"
        }
      ]
    })
  ]
}

# The embedded Falcosidekick chart creates this ServiceAccount. Chart 9.1.0
# does not expose a direct annotation value, so this narrow, declarative patch
# adds the standard GKE Workload Identity annotation after Helm creates it.
# Falcosidekick's GCP Pub/Sub client uses Application Default Credentials when
# config.gcp.credentials is empty.
resource "kubernetes_annotations" "falcosidekick_workload_identity" {
  count = var.falcosidekick_gsa_email == null ? 0 : 1

  api_version = "v1"
  kind        = "ServiceAccount"

  metadata {
    name      = "falco-falcosidekick"
    namespace = var.namespace
  }

  annotations = {
    "iam.gke.io/gcp-service-account" = var.falcosidekick_gsa_email
  }

  field_manager = "terraform-falco-workload-identity"
  force         = true

  depends_on = [helm_release.falco]
}
