output "cluster_name" {
  value = google_container_cluster.cluster.name
}

output "cluster_location" {
  value = google_container_cluster.cluster.location
}

output "cluster_endpoint" {
  value = google_container_cluster.cluster.endpoint
}

output "cluster_ca_certificate" {
  value     = google_container_cluster.cluster.master_auth[0].cluster_ca_certificate
  sensitive = true
}

output "artifact_registry_repository_id" {
  value = google_artifact_registry_repository.docker.repository_id
}

output "artifact_registry_location" {
  value = google_artifact_registry_repository.docker.location
}
