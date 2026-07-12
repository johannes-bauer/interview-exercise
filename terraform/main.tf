module "platform" {
  source = "../modules/platform"

  project_id = var.project_id
  region     = var.region
  zone       = var.zone     
}

data "google_client_config" "current" {}

module "github" {
   source = "../modules/github_ci"

   project_id        = var.project_id
   github_owner      = var.github_owner
   github_repository = var.github_repository

   repository_id = module.platform.artifact_registry_repository_id
   repository_location = module.platform.artifact_registry_location

   depends_on = [module.platform]
}

module "mlflow" {
   source = "../modules/mlflow"

   providers = {
     kubernetes = kubernetes
   }


   project_id = var.project_id
   region     = var.region
   zone       = var.zone     

   artifact_bucket_name = var.mlflow_artifact_bucket_name
   namespace            = "mlflow"
}

module "training_scoring" {
   source = "../modules/training"

   providers = {
     kubernetes = kubernetes
   }


   project_id = var.project_id
   region     = var.region
   zone       = var.zone     

   mlflow_artifact_bucket_name = var.mlflow_artifact_bucket_name
   data_bucket_name = var.training_scoring_data_bucket_name

}
