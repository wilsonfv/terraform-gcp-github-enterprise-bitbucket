# https://docs.github.com/en/enterprise-server@3.6/admin/installation/setting-up-a-github-enterprise-server-instance/installing-github-enterprise-server-on-google-cloud-platform#hardware-considerations
resource "google_compute_disk" "github-disk" {
  project = var.project_id
  name    = "github-disk"
  type    = "pd-standard"
  size    = 100
  zone    = "${var.region}-b"
}

resource "google_compute_instance" "github-enterprise" {
  project = var.project_id

  name         = "github-enterprise"
  machine_type = var.machine_type
  zone         = "${var.region}-b"

  boot_disk {
    initialize_params {
      image = var.image
    }
  }

  attached_disk {
    source = google_compute_disk.github-disk.self_link
  }

  network_interface {
    subnetwork_project = var.project_id
    subnetwork         = var.subnetwork

    access_config {
    }
  }

  tags = ["github"]
}

# https://docs.github.com/en/enterprise-server@3.6/admin/installation/setting-up-a-github-enterprise-server-instance/installing-github-enterprise-server-on-google-cloud-platform#configuring-the-firewall
resource "google_compute_firewall" "github" {
  project = var.project_id
  network = var.network

  name = "github"

  direction = "INGRESS"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22", "25", "80", "122", "443", "8080", "8443", "9418"]
  }

  allow {
    protocol = "udp"
    ports    = ["161", "1194"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["github"]
}

resource "google_dns_managed_zone" "onprem" {
  project = var.project_id

  name     = "onprem"
  dns_name = "onprem."

  visibility = "private"

  private_visibility_config {
    networks {
      network_url = var.network
    }
  }
}

resource "google_dns_record_set" "github" {
  project = var.project_id

  name = "github.${google_dns_managed_zone.onprem.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = google_dns_managed_zone.onprem.name

  rrdatas = [google_compute_instance.github-enterprise.network_interface[0].network_ip]
}

resource "google_dns_record_set" "bitbucket" {
  project = var.project_id

  name = "bitbucket.${google_dns_managed_zone.onprem.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = google_dns_managed_zone.onprem.name

  rrdatas = [google_compute_instance.bitbucket-server.network_interface[0].network_ip]
}

# duplicate Cloud DNS zone in shared-vpc because of below limitaion
# https://cloud.google.com/dns/docs/zones/zones-overview#dns_peering_limitations_and_key_points
resource "google_dns_managed_zone" "shared_vpc_onprem" {
  project = var.shared_vpc_project

  name     = "onprem"
  dns_name = "onprem."

  visibility = "private"

  private_visibility_config {
    networks {
      network_url = var.shared_vpc_network
    }
  }
}

resource "google_dns_record_set" "shared_vpc_github" {
  project = var.shared_vpc_project

  name = "github.${google_dns_managed_zone.shared_vpc_onprem.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = google_dns_managed_zone.shared_vpc_onprem.name

  rrdatas = [google_compute_instance.github-enterprise.network_interface[0].network_ip]
}

resource "google_dns_record_set" "shared_vpc_bitbucket" {
  project = var.shared_vpc_project

  name = "bitbucket.${google_dns_managed_zone.shared_vpc_onprem.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = google_dns_managed_zone.shared_vpc_onprem.name

  rrdatas = [google_compute_instance.bitbucket-server.network_interface[0].network_ip]
}

# Setting up Chrome Remote Desktop for Linux on Compute Engine
# https://cloud.google.com/architecture/chrome-desktop-remote-on-compute-engine#configuring_and_starting_the_chrome_remote_desktop_service
resource "google_compute_instance" "crdhost-autoinstall" {
  project = var.project_id

  name         = "crdhost-autoinstall"
  machine_type = "n1-standard-1"
  zone         = "${var.region}-b"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size = 50
    }
  }

  network_interface {
    subnetwork_project = var.project_id
    subnetwork         = var.subnetwork

    access_config {
    }
  }

  metadata_startup_script = file("${path.module}/chrome-remote-desktop-setup-script.sh")
}

resource "google_compute_instance" "bitbucket-server" {
  project = var.project_id

  name         = "bitbucket-server"
  machine_type = "n1-standard-1"
  zone         = "${var.region}-b"

  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-7"
      size = 50
    }
  }

  network_interface {
    subnetwork_project = var.project_id
    subnetwork         = var.subnetwork

    access_config {
    }
  }

  metadata_startup_script = file("${path.module}/bitbucket-server-setup-script.sh")
}