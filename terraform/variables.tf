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

variable "mlflow_artifact_bucket_name" {
  description = "The name of the bucket to write MLFlow artifacts to."
  type        = string
}

variable "training_scoring_data_bucket_name" {
  description = "The name of the bucket from which training and scoring data are loaded, and to which predictions are written."
  type	      = string
}

variable "github_owner" {
  description = "GitHub user or organization owning the repository."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository name, without the owner."
  type        = string
}
