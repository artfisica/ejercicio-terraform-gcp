# Ejercicio Práctico: Crear una VM en GCP usando Terraform y GitHub Actions de manera segura

## Paso 1: Configuración del Repositorio de GitHub

1. **Crear un nuevo repositorio en GitHub:**
   - Navega a GitHub y crea un nuevo repositorio público o privado.
   - Clona el repositorio en tu máquina local.

2. **Agregar archivos de configuración de Terraform:**
   - Dentro de tu repositorio, crea un directorio llamado `terraform` y navega a él.
   - Crea los siguientes archivos dentro del directorio `terraform`:

     ```plaintext
     .
     ├── main.tf
     ├── outputs.tf
     ├── provider.tf
     └── variables.tf
     ```

3. **Configurar los archivos de Terraform:**

   - `provider.tf`: Configura el proveedor de GCP.

     ```hcl
     provider "google" {
       credentials = file(var.credentials_file_path)
       project     = var.project_id
       region      = var.region
     }

     terraform {
       backend "gcs" {
         bucket  = "terraform-state-bucket"
         prefix  = "terraform/state"
       }
     }
     ```

   - `variables.tf`: Define las variables necesarias.

     ```hcl
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
       default     = "us-central1"
     }

     variable "instance_name" {
       description = "Nombre de la instancia de VM"
       type        = string
       default     = "terraform-instance"
     }

     variable "machine_type" {
       description = "Tipo de máquina para la instancia de VM"
       type        = string
       default     = "n1-standard-1"
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
     ```

   - `main.tf`: Define el recurso de la VM, la red VPC y la subred.

     ```hcl
     resource "google_compute_network" "vpc_network" {
       name                    = var.network_name
       auto_create_subnetworks = false
     }

     resource "google_compute_subnetwork" "subnetwork" {
       name          = var.subnet_name
       network       = google_compute_network.vpc_network.id
       ip_cidr_range = var.subnet_cidr
       region        = var.region
     }

     resource "google_compute_instance" "default" {
       name         = var.instance_name
       machine_type = var.machine_type
       zone         = "${var.region}-a"

       boot_disk {
         initialize_params {
           image = "debian-cloud/debian-10"
         }
       }

       network_interface {
         network    = google_compute_network.vpc_network.id
         subnetwork = google_compute_subnetwork.subnetwork.id
         access_config {
           // Ephemeral public IP
         }
       }

       metadata = {
         ssh-keys = "terraform:${file("~/.ssh/id_rsa.pub")}"
       }
     }
     ```

   - `outputs.tf`: Define las salidas del recurso.

     ```hcl
     output "instance_name" {
       value = google_compute_instance.default.name
     }

     output "instance_zone" {
       value = google_compute_instance.default.zone
     }

     output "instance_public_ip" {
       value = google_compute_instance.default.network_interface[0].access_config[0].nat_ip
     }

     output "network_name" {
       value = google_compute_network.vpc_network.name
     }

     output "subnet_name" {
       value = google_compute_subnetwork.subnetwork.name
     }

     output "subnet_cidr" {
       value = google_compute_subnetwork.subnetwork.ip_cidr_range
     }
     ```

## Paso 2: Configurar GitHub Actions

1. **Crear el archivo de workflow:**
   - Dentro de tu repositorio, crea un directorio `.github/workflows` y navega a él.
   - Crea un archivo llamado `terraform.yml`.

     ```yaml
     name: 'Terraform Apply'

     on:
       push:
         branches:
           - main

     jobs:
       terraform:
         name: 'Terraform Apply'
         runs-on: ubuntu-latest

         steps:
           - name: 'Checkout GitHub repository'
             uses: actions/checkout@v2

           - name: 'Set up Terraform'
             uses: hashicorp/setup-terraform@v1
             with:
               terraform_version: 1.0.0

           - name: 'Authenticate to Google Cloud'
             env:
               GCP_PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}
               GOOGLE_APPLICATION_CREDENTIALS: ${{ secrets.GOOGLE_APPLICATION_CREDENTIALS }}
             run: |
               echo "${{ secrets.GOOGLE_APPLICATION_CREDENTIALS }}" > $HOME/gcloud.json
               gcloud auth activate-service-account --key-file=$HOME/gcloud.json
               gcloud config set project $GCP_PROJECT_ID

           - name: 'Initialize Terraform'
             run: terraform -chdir=terraform init
             env:
               GOOGLE_APPLICATION_CREDENTIALS: ${{ secrets.GOOGLE_APPLICATION_CREDENTIALS }}
               TF_VAR_credentials_file_path: $HOME/gcloud.json
               TF_VAR_project_id: ${{ secrets.GCP_PROJECT_ID }}

           - name: 'Terraform Plan'
             run: terraform -chdir=terraform plan -out=plan.tfplan
             env:
               GOOGLE_APPLICATION_CREDENTIALS: ${{ secrets.GOOGLE_APPLICATION_CREDENTIALS }}
               TF_VAR_credentials_file_path: $HOME/gcloud.json
               TF_VAR_project_id: ${{ secrets.GCP_PROJECT_ID }}

           - name: 'Terraform Apply'
             run: terraform -chdir=terraform apply -auto-approve plan.tfplan
             env:
               GOOGLE_APPLICATION_CREDENTIALS: ${{ secrets.GOOGLE_APPLICATION_CREDENTIALS }}
               TF_VAR_credentials_file_path: $HOME/gcloud.json
               TF_VAR_project_id: ${{ secrets.GCP_PROJECT_ID }}
     ```

2. **Configurar los secretos en GitHub:**
   - Ve a la configuración de tu repositorio en GitHub.
   - Navega a la sección de **Secrets** y añade los siguientes secretos:
     - `GCP_PROJECT_ID`: El ID de tu proyecto de GCP.
     - `GOOGLE_APPLICATION_CREDENTIALS`: El contenido del archivo JSON de la cuenta de servicio de GCP.

## Paso 3: Ejecución y Verificación

1. **Push al Repositorio:**
   - Añade, commitea y haz push de tus cambios al repositorio de GitHub.

     ```bash
     git add .
     git commit -m "Add Terraform configuration and GitHub Action"
     git push origin main
     ```

2. **Verificar la Ejecución:**
   - Navega a la pestaña **Actions** en tu repositorio de GitHub.
   - Verifica que el workflow se ejecute correctamente y que la VM se cree en tu proyecto de GCP.

## Paso 4: Buenas Prácticas de Seguridad

1. **Principio de Menor Privilegio:**
   - Asegúrate de que la cuenta de servicio usada tenga solo los permisos necesarios.
   - Utiliza roles personalizados si es necesario.

2. **Almacenamiento Seguro de Credenciales:**
   - Nunca almacenes credenciales en el código fuente.
   - Usa GitHub Secrets para gestionar credenciales y variables sensibles.

3. **Cifrado y Control de Acceso:**
   - Asegúrate de que los archivos de estado de Terraform se almacenen de manera segura y estén cifrados.
   - Utiliza Google Cloud Storage con IAM adecuado para almacenar los estados de Terraform.

## Resumen

Este ejercicio te guía a través de la configuración de un repositorio de GitHub, la configuración de Terraform para desplegar una red VPC, una subred y una VM en GCP, y la creación de un workflow de GitHub Actions para automatizar este proceso.
