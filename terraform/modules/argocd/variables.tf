variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "argocd_domain" {
  description = "Domain name for ArgoCD server"
  type        = string
  default     = "argocd.local"
}

variable "service_type" {
  description = "Kubernetes service type for ArgoCD server"
  type        = string
  default     = "LoadBalancer"
}

variable "enable_ingress" {
  description = "Enable ingress for ArgoCD server"
  type        = bool
  default     = false
}

variable "ha_mode" {
  description = "Enable high availability mode with multiple replicas"
  type        = bool
  default     = false
}

variable "cluster_ready" {
  description = "Dependency to ensure cluster is ready"
  type        = any
  default     = null
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
