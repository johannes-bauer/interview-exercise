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

variable "cluster_name" {
  type    = string
  default = "ml-training-cluster"
}

variable "artifact_registry_repository_id" {
  type    = string
  default = "ml-training-images"
}
