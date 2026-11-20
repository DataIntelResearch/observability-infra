output "cluster_name" {
  value = google_container_cluster.obs.name
}

output "cluster_location" {
  value = google_container_cluster.obs.location
}

output "get_credentials_command" {
  value = "gcloud container clusters get-credentials ${google_container_cluster.obs.name} --zone ${google_container_cluster.obs.location} --project ${var.project_id}"
}
