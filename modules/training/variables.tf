variable "project_id" {
  description = "The GCP project ID."
  type        = string
}

variable "region" {
  description = "The region for this project."
  type        = string
}

variable "zone" {
  description = "The zone for this project."
  type        = string
}

variable "data_bucket_name" {
  description = "The name of the bucket for training data, scoring data, and predictions."
  type        = string
}

variable "mlflow_artifact_bucket_name" {
  description = "The name of the bucket that the MLFlow service and every service that need access to artifacts uses."
  type	      = string
}
