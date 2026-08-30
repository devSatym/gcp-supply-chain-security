# Falco + Falcosidekick for AKS.
#
# The Azure Event Hubs output in Falcosidekick uses DefaultAzureCredential.
# Supplying workloadIdentityClientID makes the chart create both the required
# ServiceAccount annotation and the Azure Workload Identity pod label; no SAS
# policy or Event Hubs connection string is mounted in the cluster.

locals {
  eventhub_enabled = var.enable_falcosidekick && var.eventhub_name != null && var.eventhub_namespace_fqdn != null && var.falcosidekick_client_id != null
}

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
          { debug = false },
          local.eventhub_enabled ? {
            azure = {
              # The Falcosidekick Helm chart turns this into the ServiceAccount
              # annotation and azure.workload.identity/use pod label.
              workloadIdentityClientID = var.falcosidekick_client_id
              eventHub = {
                namespace       = var.eventhub_namespace_fqdn
                name            = var.eventhub_name
                minimumpriority = lower(var.minimum_priority)
              }
            }
          } : {},
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
    }),
  ]
}
