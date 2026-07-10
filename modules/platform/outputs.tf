output "cluster_name" {
  value = google_container_cluster.cluster.name
}

output "cluster_location" {
  value = google_container_cluster.cluster.location
}

output "artifact_registry_repository_id" {
  value = google_artifact_registry_repository.docker.repository_id
}

output "artifact_registry_location" {
  value = google_artifact_registry_repository.docker.location
}
