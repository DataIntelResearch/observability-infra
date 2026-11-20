variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "Region for the VPC subnet."
  type        = string
  default     = "us-east1"
}

variable "zone" {
  description = "Zone for the (zonal) GKE cluster and node pool."
  type        = string
  default     = "us-east1-b"
}

variable "cluster_name" {
  description = "Name of the GKE cluster."
  type        = string
  default     = "obs"
}

variable "machine_type" {
  description = "Machine type for the node pool."
  type        = string
  default     = "e2-standard-4"
}

variable "spot" {
  description = "Use Spot VMs for nodes (much cheaper, but Google can reclaim them)."
  type        = bool
  default     = false
}
