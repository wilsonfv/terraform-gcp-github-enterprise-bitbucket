variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "machine_type" {
  type = string
  default = "n1-standard-8"
}

variable "image" {
  type = string
  description = "https://docs.github.com/en/enterprise-server@3.6/admin/installation/setting-up-a-github-enterprise-server-instance/installing-github-enterprise-server-on-google-cloud-platform#selecting-the-github-enterprise-server-image"
  default = "github-enterprise-public/github-enterprise-3-7-4"
}

variable "network" {
  type = string
}

variable "subnetwork" {
  type = string
}

variable "shared_vpc_project" {
  type = string
}

variable "shared_vpc_network" {
  type = string
}