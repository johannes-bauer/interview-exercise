resource "google_service_account" "model_workload" {
  project      = var.project_id
  account_id   = "model-workload"
  display_name = "Training and scoring workload"
}

resource "kubernetes_namespace_v1" "training" {
  metadata {
    name = "training"
  }
}

resource "kubernetes_service_account_v1" "model_workload" {
  metadata {
    name      = "model-workload"
    namespace = kubernetes_namespace_v1.training.metadata[0].name

    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.model_workload.email
    }
  }
}

resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.model_workload.name
  role               = "roles/iam.workloadIdentityUser"

  member = "serviceAccount:${var.project_id}.svc.id.goog[training/model-workload]"
}

resource "google_storage_bucket" "training_data" {
  project  = var.project_id
  name     = var.data_bucket_name
  location = var.region

  # Manage access exclusively through IAM rather than legacy object ACLs.
  uniform_bucket_level_access = true

  # Appropriate for this disposable exercise:
  # terraform destroy may delete the bucket even when artifacts remain.
  # In production, this would usually be false.
  force_destroy = true
}

resource "google_storage_bucket_iam_member" "data_access" {
  bucket = google_storage_bucket.training_data.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.model_workload.email}"
}

resource "google_storage_bucket_iam_member" "mlflow_artifact_access" {
  bucket = var.mlflow_artifact_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.model_workload.email}"
}
