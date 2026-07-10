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

variable "artifact_bucket_name" {
  description = "The name of the bucket for MLFlow artifacts."
  type        = string
}

variable "namespace" {
  type    = string
  default = "mlflow"
}
