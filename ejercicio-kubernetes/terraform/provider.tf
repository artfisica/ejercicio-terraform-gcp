provider "google" {
  credentials = file(var.credentials_file_path)
  project     = var.project_id
  region      = var.region
}

terraform {
  backend "gcs" {
    bucket  = "terraform-state-bucket-goes"
    prefix  = "terraform/state/kubernetes-cluster"
  }
}
