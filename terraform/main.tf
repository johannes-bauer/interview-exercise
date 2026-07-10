module "platform" {
  source = "../modules/platform"

  project_id = var.project_id
  region     = var.region
  zone       = var.zone     
}

module "mlflow" {
  source = "../modules/mlflow"

  project_id = var.project_id
  region     = var.region
  zone       = var.zone     

  artifact_bucket_name = "mlflow-bucket"
  namespace            = "mlflow"

}
