provider "kubernetes" {
  host = "https://${module.platform.cluster_endpoint}"

  token = data.google_client_config.current.access_token

  cluster_ca_certificate = base64decode(
    module.platform.cluster_ca_certificate
  )
}
