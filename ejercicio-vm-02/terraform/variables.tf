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
  default     = "europe-west6" ## "us-central1"
}

variable "instance_name" {
  description = "Nombre de la instancia de VM"
  type        = string
  default     = "terraform-instance-server"
}

variable "machine_type" {
  description = "Tipo de máquina para la instancia de VM"
  type        = string
  default     = "n1-standard-1"
}

variable "network_name" {
  description = "El nombre de la red VPC a crear"
  type        = string
  default     = "terraform-vm-network"
}

variable "subnet_name" {
  description = "El nombre de la subred a crear"
  type        = string
  default     = "terraform-vm-subnet"
}

variable "subnet_cidr" {
  description = "El rango CIDR para la subred"
  type        = string
  default     = "10.0.0.0/24"
}

