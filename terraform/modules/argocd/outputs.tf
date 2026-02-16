output "argocd_namespace" {
  description = "Namespace where ArgoCD is deployed"
  value       = helm_release.argocd.namespace
}

output "argocd_release_name" {
  description = "Helm release name for ArgoCD"
  value       = helm_release.argocd.name
}

output "argocd_server_url" {
  description = "ArgoCD server URL (use kubectl port-forward or LoadBalancer IP)"
  value       = "https://${var.argocd_domain}"
}

output "access_instructions" {
  description = "Instructions to access ArgoCD"
  value       = <<-EOT
    To access ArgoCD:
    
    1. Get the initial admin password:
       kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
    
    2. Port forward to access the UI:
       kubectl port-forward svc/argocd-server -n argocd 8080:443
    
    3. Access ArgoCD at: https://localhost:8080
       Username: admin
       Password: (from step 1)
    
    4. Or get LoadBalancer URL:
       kubectl get svc argocd-server -n argocd
  EOT
}
