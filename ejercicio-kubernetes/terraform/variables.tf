variable "credentials_file_path" {
  description = "Ruta al archivo de clave de la cuenta de servicio"
  type        = string
}

variable "project_id" {
  description = "El ID del proyecto de GCP"
  type        = string
}

variable "region" {
  description = "La región para desplegar los recursos"
  type        = string
  default     = "europe-west4" ## "us-central1"
}

variable "cluster_name" {
  description = "Nombre del clúster de Kubernetes"
  type        = string
  default     = "terraform-cluster"
}

variable "node_count" {
  description = "Número de nodos del clúster"
  type        = number
  default     = 3
}

variable "machine_type" {
  description = "Tipo de máquina para los nodos del clúster"
  type        = string
  default     = "e2-medium"
}

variable "network_name" {
  description = "El nombre de la red VPC a crear"
  type        = string
  default     = "terraform-network"
}

variable "subnet_name" {
  description = "El nombre de la subred a crear"
  type        = string
  default     = "terraform-subnet"
}

variable "subnet_cidr" {
  description = "El rango CIDR para la subred"
  type        = string
  default     = "10.0.0.0/24"
}
