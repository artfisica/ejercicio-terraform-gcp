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

resource "google_compute_firewall" "default-allow-http" {
  name    = "default-allow-http"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]
}

resource "google_compute_instance" "default" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = "${var.region}-a"

  tags = ["http-server"]

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

  metadata_startup_script = <<-EOT
    #!/bin/bash

    # Update and install nginx
    apt-get update
    apt-get install -y nginx

    # Create a custom HTML page
    cat <<EOF > /var/www/html/index.nginx-debian.html
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>GOES Demo</title>
        <style>
            body { font-family: Arial, sans-serif; background-color: #f0f0f0; color: #333; text-align: center; margin-top: 50px; }
            h1 { color: #007BFF; }
            p { font-size: 1.2em; }
        </style>
    </head>
    <body>
        <h1>Welcome to the GOES Demo Server!</h1>
        <p>Hola, GOES! - demo</p>
        <p>This is a custom Nginx server setup with Terraform.</p>
    </body>
    </html>
    EOF

    # Install monitoring tools
    apt-get install -y htop curl

    # Set up a basic cron job for server health checks
    echo "* * * * * root curl -fsS --retry 3 http://localhost || echo 'Nginx server is down!' | mail -s 'Server Alert' root@localhost" > /etc/cron.d/nginx-monitor

    # Restart nginx to apply changes
    systemctl restart nginx

    # Enable and start the cron service
    systemctl enable cron
    systemctl start cron
  EOT
}
