locals {
  namespace            = "mlflow"
  app_name             = "mlflow"
  port                 = 5000
  google_service_account_id = "mlflow-server"
}

# ---------------------------------------------------------------------------
# Artifact storage
# ---------------------------------------------------------------------------

resource "google_storage_bucket" "mlflow_artifacts" {
  project  = var.project_id
  name     = var.artifact_bucket_name
  location = var.region

  # Manage access exclusively through IAM rather than legacy object ACLs.
  uniform_bucket_level_access = true

  # Appropriate for this disposable exercise:
  # terraform destroy may delete the bucket even when artifacts remain.
  # In production, this would usually be false.
  force_destroy = true
}

# ---------------------------------------------------------------------------
# Google identity used by the MLflow workload
# ---------------------------------------------------------------------------

resource "google_service_account" "mlflow" {
  project      = var.project_id
  account_id   = local.google_service_account_id
  display_name = "MLflow tracking server"
  description  = "Identity used by the MLflow tracking server in GKE"
}

# Give MLflow read/write/delete access to objects in this bucket only.
# This does not grant permissions across every bucket in the project.
resource "google_storage_bucket_iam_member" "mlflow_artifacts" {
  bucket = google_storage_bucket.mlflow_artifacts.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.mlflow.email}"
}

# ---------------------------------------------------------------------------
# Kubernetes namespace and identity
# ---------------------------------------------------------------------------

resource "kubernetes_namespace_v1" "mlflow" {
  metadata {
    name = local.namespace
  }
}

resource "kubernetes_service_account_v1" "mlflow" {
  metadata {
    name      = local.app_name
    namespace = kubernetes_namespace_v1.mlflow.metadata[0].name

    # Associates this Kubernetes ServiceAccount with the Google
    # service account above.
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.mlflow.email
    }
  }
}

# Permit this specific Kubernetes ServiceAccount to impersonate the
# Google service account through GKE Workload Identity Federation.
resource "google_service_account_iam_member" "mlflow_workload_identity" {
  service_account_id = google_service_account.mlflow.name
  role               = "roles/iam.workloadIdentityUser"

  member = "serviceAccount:${var.project_id}.svc.id.goog[${local.namespace}/${local.app_name}]"
}

# ---------------------------------------------------------------------------
# Persistent backend store
# ---------------------------------------------------------------------------

resource "kubernetes_persistent_volume_claim_v1" "mlflow_data" {
  metadata {
    name      = "mlflow-data"
    namespace = kubernetes_namespace_v1.mlflow.metadata[0].name
  }

  wait_until_bound = false

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "1Gi"
      }
    }

    # No storage_class_name:
    # use the default dynamically provisioned GKE storage class.
  }
}

# ---------------------------------------------------------------------------
# MLflow tracking server
# ---------------------------------------------------------------------------

resource "kubernetes_deployment_v1" "mlflow" {
  metadata {
    name      = local.app_name
    namespace = kubernetes_namespace_v1.mlflow.metadata[0].name

    labels = {
      app = local.app_name
    }
  }

  spec {
    # SQLite does not support a horizontally scaled MLflow server safely.
    replicas = 1

    selector {
      match_labels = {
        app = local.app_name
      }
    }

    template {
      metadata {
        labels = {
          app = local.app_name
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.mlflow.metadata[0].name

        container {
          name  = local.app_name
          image = "${var.region}-docker.pkg.dev/${var.project_id}/ml-training-images/mlflow:latest"
          image_pull_policy = "Always"

          command = ["mlflow"]

          args = [
            "server",
            "--host=0.0.0.0",
            "--port=${local.port}",
            "--backend-store-uri=sqlite:////mlflow-data/mlflow.db",
            "--default-artifact-root=gs://${google_storage_bucket.mlflow_artifacts.name}",
            "--no-serve-artifacts",
          ]

          port {
            name           = "http"
            container_port = local.port
            protocol       = "TCP"
          }

          volume_mount {
            name       = "mlflow-data"
            mount_path = "/mlflow-data"
          }

          resources {
            requests = {
              cpu    = "250m"
              memory = "512Mi"
            }

            limits = {
              cpu    = "1"
              memory = "1Gi"
            }
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = local.port
            }

            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 3
            failure_threshold     = 6
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = local.port
            }

            initial_delay_seconds = 30
            period_seconds        = 20
            timeout_seconds       = 3
            failure_threshold     = 3
          }
        }

        volume {
          name = "mlflow-data"

          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.mlflow_data.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    google_storage_bucket_iam_member.mlflow_artifacts,
    google_service_account_iam_member.mlflow_workload_identity,
  ]
}

# ---------------------------------------------------------------------------
# Internal Kubernetes networking
# ---------------------------------------------------------------------------

resource "kubernetes_service_v1" "mlflow" {
  metadata {
    name      = local.app_name
    namespace = kubernetes_namespace_v1.mlflow.metadata[0].name
  }

  spec {
    selector = {
      app = local.app_name
    }

    port {
      name        = "http"
      port        = local.port
      target_port = local.port
      protocol    = "TCP"
    }

    # Internal cluster access only. This avoids creating a public
    # load balancer and exposing an unauthenticated MLflow server.
    type = "ClusterIP"
  }
}
