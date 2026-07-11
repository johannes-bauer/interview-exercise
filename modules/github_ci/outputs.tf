output "workload_identity_provider" {
  value = google_iam_workload_identity_pool_provider.github.name
}

output "image_builder_service_account" {
  value = google_service_account.github_image_builder.email
}
