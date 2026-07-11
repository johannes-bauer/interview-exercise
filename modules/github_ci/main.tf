data "google_project" "current" {
  project_id = var.project_id
}

resource "google_service_account" "github_image_builder" {
  project      = var.project_id
  account_id   = "github-image-builder"
  display_name = "GitHub image builder"
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  # Reject tokens from every repository except this exact one.
  attribute_condition = "assertion.repository == '${var.github_owner}/${var.github_repository}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "github_identity" {
  service_account_id = google_service_account.github_image_builder.name
  role               = "roles/iam.workloadIdentityUser"

  member = "principalSet://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github.workload_identity_pool_id}/attribute.repository/${var.github_owner}/${var.github_repository}"
}

resource "google_artifact_registry_repository_iam_member" "github_writer" {
  project    = var.project_id
  location   = var.repository_location
  repository = var.repository_id

  role   = "roles/artifactregistry.writer"
  member = "serviceAccount:${google_service_account.github_image_builder.email}"
}
