# Azure Kubernetes add-ons.
#
# This module deliberately concentrates the active admission controller in a
# small, portable unit. The calling root supplies providers configured for the
# private AKS endpoint, so it must run from a controlled VNet/DNS-capable host.

locals {
  kyverno_values_template = coalesce(
    var.kyverno_values_template_path,
    "${path.module}/../../../policy/azure/kyverno/values.yaml",
  )
  kyverno_policy_template = coalesce(
    var.kyverno_policy_template_path,
    "${path.module}/../../../policy/azure/kyverno/block-unsigned-images.yaml",
  )

  kyverno_values = templatefile(local.kyverno_values_template, {
    kyverno_client_id = var.kyverno_client_id
  })

  kyverno_policy = yamldecode(templatefile(local.kyverno_policy_template, {
    acr_login_server       = var.acr_login_server
    application_repository = var.application_repository
    cosign_repository      = var.cosign_repository
  }))

  argocd_values = file("${path.module}/argocd-values.yaml")

  # Keep the reviewed Argo Application manifest as the single source of
  # truth. The local chart only packages it after Argo's CRDs are installed.
  argocd_application = yamldecode(file("${path.module}/../../../argocd/supply-chain-azure-demo-app.yaml"))
}

resource "helm_release" "kyverno" {
  name             = "kyverno"
  repository       = "https://kyverno.github.io/kyverno/"
  chart            = "kyverno"
  version          = var.kyverno_chart_version
  namespace        = var.kyverno_namespace
  create_namespace = true
  wait             = true
  atomic           = true
  timeout          = 600

  values = [local.kyverno_values]
}

# The Kyverno CRD is created by the first Helm release. Installing the policy
# through a second Helm release keeps the dependency in Helm's apply path and
# avoids Kubernetes-provider discovery of a CRD that does not exist at plan
# time on a new cluster.
resource "helm_release" "kyverno_policy" {
  count = var.install_policy ? 1 : 0

  name             = "kyverno-policy"
  chart            = "${path.module}/policy-chart"
  namespace        = var.kyverno_namespace
  create_namespace = false
  wait             = true
  atomic           = true
  timeout          = 300

  values = [yamlencode({
    policy = local.kyverno_policy
  })]

  depends_on = [helm_release.kyverno]
}

resource "helm_release" "metrics_server" {
  count = var.enable_metrics_server ? 1 : 0

  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  version          = var.metrics_server_chart_version
  namespace        = "kube-system"
  create_namespace = false

  set {
    name  = "resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "resources.requests.memory"
    value = "200Mi"
  }
}

resource "helm_release" "argocd" {
  count = var.install_argocd ? 1 : 0

  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = "argocd"
  create_namespace = true
  wait             = true
  atomic           = true
  timeout          = 600

  values = [local.argocd_values]

  depends_on = [helm_release.kyverno]
}

resource "helm_release" "argocd_application" {
  count = var.install_argocd ? 1 : 0

  name             = "supply-chain-azure-demo-app"
  chart            = "${path.module}/argocd-application-chart"
  namespace        = "argocd"
  create_namespace = false
  wait             = true
  atomic           = true
  timeout          = 300

  values = [yamlencode({
    application = local.argocd_application
  })]

  depends_on = [helm_release.argocd]
}
