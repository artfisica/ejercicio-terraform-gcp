# Ejercicio Práctico: Desplegar un Clúster de Kubernetes en GCP usando Terraform y GitHub Actions

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
       description = "La región para desplegar recursos"
       type        = string
       default     = "us-central1"
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
     ```

   - `main.tf`: Define el recurso del clúster de Kubernetes, la red VPC y la subred.

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

     resource "google_container_cluster" "primary" {
       name     = var.cluster_name
       location = var.region

       initial_node_count = var.node_count

       node_config {
         machine_type = var.machine_type

         oauth_scopes = [
           "https://www.googleapis.com/auth/logging.write",
           "https://www.googleapis.com/auth/monitoring"
         ]
       }

       network    = google_compute_network.vpc_network.name
       subnetwork = google_compute_subnetwork.subnetwork.name
     }

     resource "google_container_node_pool" "primary_nodes" {
       name       = "primary-node-pool"
       location   = var.region
       cluster    = google_container_cluster.primary.name
       node_count = var.node_count

       node_config {
         machine_type = var.machine_type
       }
     }
     ```

   - `outputs.tf`: Define las salidas del recurso.

     ```hcl
     output "cluster_name" {
       value = google_container_cluster.primary.name
     }

     output "cluster_endpoint" {
       value = google_container_cluster.primary.endpoint
     }

     output "client_certificate" {
       value = google_container_cluster.primary.master_auth.0.client_certificate
     }

     output "client_key" {
       value = google_container_cluster.primary.master_auth.0.client_key
     }

     output "cluster_ca_certificate" {
       value = google_container_cluster.primary.master_auth.0.cluster_ca_certificate
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

1. **Crear el archivo de workflow para el plan de Terraform:**
   - Dentro de tu repositorio, crea un directorio `.github/workflows` y navega a él.
   - Crea un archivo llamado `terraform-plan.yml`.

     ```yaml
     name: 'Terraform Plan'

     on:
       pull_request:
         branches:
           - main

     jobs:
       terraform:
         name: 'Terraform Plan'
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
     ```

2. **Crear el archivo de workflow para aplicar Terraform:**
   - En el mismo directorio `.github/workflows`, crea un archivo llamado `terraform-apply.yml`.

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

           - name: 'Terraform Apply'
             run: terraform -chdir=terraform apply -auto-approve plan.tfplan
             env:
               GOOGLE_APPLICATION_CREDENTIALS: ${{ secrets.GOOGLE_APPLICATION_CREDENTIALS }}
               TF_VAR_credentials_file_path: $HOME/gcloud.json
               TF_VAR_project_id: ${{ secrets.GCP_PROJECT_ID }}
     ```

3. **Configurar los secretos en GitHub:**
   - Ve a la configuración de tu repositorio en GitHub.
   - Navega a la sección de **Secrets** y añade los siguientes secretos:
     - `GCP_PROJECT_ID`: El ID de tu proyecto de GCP.
     - `GOOGLE_APPLICATION_CREDENTIALS`: El contenido del archivo JSON de la cuenta de servicio de GCP.

## Paso 3: Ejecución y Verificación

1. **Push al Repositorio:**
   - Añade, commitea y haz push de tus cambios al repositorio de GitHub.

     ```bash
     git add .
     git commit -m "Add Terraform configuration and GitHub Actions"
     git push origin main
     ```

2. **Crear un Pull Request:**
   - Navega a tu repositorio en GitHub.
   - Crea un nuevo pull request para fusionar tus cambios a la rama `main`.

3. **Verificar la Ejecución del Plan:**
   - Navega a la pestaña **Actions** en tu repositorio de GitHub.
   - Verifica que el workflow del plan (`terraform-plan.yml`) se ejecute correctamente en el pull request.

4. **Fusionar el Pull Request:**
   - Una vez que el plan de Terraform se ejecute correctamente y se apruebe el pull request, fusiónalo a la rama `main`.

5. **Verificar la Ejecución del Apply:**
   - Después de fusionar el pull request, el workflow de aplicar (`terraform-apply.yml`) se ejecutará automáticamente.
   - Verifica que el workflow se ejecute correctamente y que el clúster de Kubernetes se cree en tu proyecto de GCP.

## Paso 4: Autenticación de Usuarios

1. **Crear cuentas de servicio para usuarios:**
   - Ve a la sección de IAM & Admin en Google Cloud Console.
   - Crea nuevas cuentas de servicio para cada usuario que necesite acceder al clúster de Kubernetes.
   - Asigna los permisos necesarios, como `Kubernetes Engine Developer` o `Viewer`, según sea necesario.

2. **Configurar `kubeconfig` para acceder al clúster:**
   - Genera un archivo `kubeconfig` para cada cuenta de servicio.
   - Usa el comando `gcloud` para configurar el acceso:

     ```bash
     gcloud container clusters get-credentials [CLUSTER_NAME] --zone [ZONE] --project [PROJECT_ID]
     ```

   - Configura el `kubeconfig` para usar las credenciales de la cuenta de servicio.

## Paso 5: Buenas Prácticas de Seguridad

1. **Principio de Menor Privilegio:**
   - Asegúrate de que las cuentas de servicio usadas tengan solo los permisos necesarios.
   - Utiliza roles personalizados si es necesario.

2. **Almacenamiento Seguro de Credenciales:**
   - Nunca almacenes credenciales en el código fuente.
   - Usa GitHub Secrets para gestionar credenciales y variables sensibles.

3. **Cifrado y Control de Acceso:**
   - Asegúrate de que los archivos de estado de Terraform se almacenen de manera segura y estén cifrados.
   - Utiliza Google Cloud Storage con IAM adecuado para almacenar los estados de Terraform.

## Resumen

Este ejercicio te guía a través de la configuración de un repositorio de GitHub, la configuración de Terraform para desplegar una red VPC, una subred y un clúster de Kubernetes con 3 nodos en GCP, y la creación de workflows de GitHub Actions para automatizar este proceso. También incluye la configuración de la autenticación de usuarios mediante cuentas de servicio en GCP.
