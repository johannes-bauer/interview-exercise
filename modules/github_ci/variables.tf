variable "project_id" {
  description = "The GCP project ID."
  type        = string
}

variable "github_owner" {
  description = "GitHub user or organization owning the repository."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository name, without the owner."
  type        = string
}

variable "repository_id" {
  description = "The ID of the repository to push to"
  type        = string
}

variable "repository_location" {
  description = "The location of the repository to push to"
  type        = string
}
