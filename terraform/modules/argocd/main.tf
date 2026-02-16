# ArgoCD Helm Release
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "5.51.0"
  namespace        = "argocd"
  create_namespace = true

  values = [
    yamlencode({
      global = {
        domain = var.argocd_domain
      }

      server = {
        replicas = var.ha_mode ? 2 : 1
        
        service = {
          type = var.service_type
        }

        ingress = {
          enabled = var.enable_ingress
          ingressClassName = "alb"
          annotations = {
            "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
            "alb.ingress.kubernetes.io/target-type"     = "ip"
            "alb.ingress.kubernetes.io/backend-protocol" = "HTTPS"
          }
          hosts = [var.argocd_domain]
        }
      }

      repoServer = {
        replicas = var.ha_mode ? 2 : 1
      }

      applicationSet = {
        enabled = true
        replicas = var.ha_mode ? 2 : 1
      }

      controller = {
        replicas = var.ha_mode ? 2 : 1
      }

      redis-ha = {
        enabled = var.ha_mode
      }
    })
  ]

  depends_on = [var.cluster_ready]
}

# Wait for ArgoCD to be ready
resource "time_sleep" "wait_for_argocd" {
  depends_on = [helm_release.argocd]
  create_duration = "30s"
}
