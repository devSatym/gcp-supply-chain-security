# modules/falco/main.tf
#
# Deploys Falco (eBPF runtime detection) + Falcosidekick (alert routing)
# onto an existing private, VPC-native GKE cluster. Falco itself needs
# no cloud credentials. Falcosidekick's GCP Pub/Sub output has no
# Workload Identity support in this chart (confirmed against 9.1.0 -
# its pod's serviceAccountName is hardcoded by the chart, not
# configurable) - it authenticates via a static base64-encoded JSON
# key instead, same pattern this repo already uses for Ratify's GAR
# auth (see docs/decisions/ratify-gcp-auth-tradeoff.md).
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

        config = merge(
          {
            debug = false
          },
          {
            gcp = merge(
              {
                credentials = var.falcosidekick_gcp_credentials_b64
              },
              var.alert_pubsub_topic_id != null ? {
                pubsub = {
                  projectid = var.project_id
                  topic     = split("/", var.alert_pubsub_topic_id)[3]
                }
              } : {}
            )
          }
        )
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