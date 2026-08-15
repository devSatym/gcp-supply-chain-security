# Kubernetes Add-ons Module — GKE
#
# Note on parity with the AWS/EKS blueprint:
#   - Cluster Autoscaler  -> handled natively by GKE node pool `autoscaling {}`
#                            blocks in the gke module (no separate addon needed).
#                            Optionally enable cluster-level Node Auto-Provisioning
#                            via var.enable_node_auto_provisioning.
#   - AWS LB Controller   -> handled natively by GKE's built-in Ingress/Gateway
#                            controller (addons_config.http_load_balancing in the
#                            gke module). No separate addon needed.
#   - External DNS        -> deployed here via Helm, wired to Cloud DNS through
#                            Workload Identity.
#   - Metrics Server       -> NOT deployed by default. GKE Standard clusters
#                            ship a built-in metrics-server in kube-system
#                            automatically (used for HPA). Set
#                            var.enable_metrics_server = true only if you've
#                            explicitly removed the built-in one.
# -----------------------------------------------------------------------------

locals {
  labels = merge(
    var.labels,
    {
      environment = var.environment
      owner       = var.owner
      project     = var.project_label
      cost_center = var.cost_center
      managed_by  = "terraform"
    }
  )
}

# Metrics Server
resource "helm_release" "metrics_server" {
  count = var.enable_metrics_server ? 1 : 0

  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  version          = var.metrics_server_chart_version
  namespace        = "kube-system"
  create_namespace = false

  set = [
    {
      name  = "resources.requests.cpu"
      value = "100m"
    },
    {
      name  = "resources.requests.memory"
      value = "200Mi"
    },
  ]
}

# External DNS — Google Service Account + Workload Identity binding
resource "google_service_account" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  project      = var.project_id
  account_id   = "${substr(var.cluster_name, 0, 20)}-ext-dns"
  display_name = "External DNS for ${var.cluster_name}"
}

resource "google_project_iam_member" "external_dns_dns_admin" {
  count = var.enable_external_dns ? 1 : 0

  project = var.project_id
  role    = "roles/dns.admin"
  member  = "serviceAccount:${google_service_account.external_dns[0].email}"
}

resource "google_service_account_iam_member" "external_dns_workload_identity" {
  count = var.enable_external_dns ? 1 : 0

  service_account_id = google_service_account.external_dns[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[external-dns/external-dns]"
}

resource "kubernetes_namespace_v1" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  metadata {
    name   = "external-dns"
    labels = local.labels
  }
}

resource "kubernetes_service_account_v1" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  metadata {
    name      = "external-dns"
    namespace = kubernetes_namespace_v1.external_dns[0].metadata[0].name
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.external_dns[0].email
    }
  }
}

resource "helm_release" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = var.external_dns_chart_version
  namespace  = kubernetes_namespace_v1.external_dns[0].metadata[0].name

  set = [
    {
      name  = "provider"
      value = "google"
    },
    {
      name  = "google.project"
      value = var.project_id
    },
    {
      name  = "serviceAccount.create"
      value = "false"
    },
    {
      name  = "serviceAccount.name"
      value = kubernetes_service_account_v1.external_dns[0].metadata[0].name
    },
    {
      name  = "domainFilters[0]"
      value = var.dns_domain_filter
    },
    {
      name  = "policy"
      value = var.external_dns_policy
    },
  ]

  depends_on = [kubernetes_service_account_v1.external_dns]
}

# Note: GKE Node Auto-Provisioning (cluster-level autoscaling of whole node
# pools, not just node count within a pool) is configured on the
# google_container_cluster resource itself via a `cluster_autoscaling {}`
# block in the gke module, not here. This module only ships add-ons that run
# as workloads inside the cluster.
