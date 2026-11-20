variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "zone" {
  description = "Zone of the GKE cluster created by the infra stack."
  type        = string
  default     = "us-east1-b"
}

variable "cluster_name" {
  description = "Name of the GKE cluster created by the infra stack."
  type        = string
  default     = "obs"
}

variable "kube_prometheus_stack_version" {
  description = "Pinned kube-prometheus-stack Helm chart version."
  type        = string
  default     = "93.6.0"
}
