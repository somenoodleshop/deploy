terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    docker = {
      source = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
  backend "s3" {
    bucket = ""
    key = "terraform.tfstate"
    region = "us-east-1"
    endpoints = { s3 = "https://nyc3.digitaloceanspaces.com" }
    encrypt = true
    skip_credentials_validation = true
    skip_metadata_api_check = true
    skip_requesting_account_id = true
    skip_region_validation = true
  }
}

variable "digitalocean_ssh_key_name" { type = string }
variable "digitalocean_token" { type = string }
variable "private_key" { type = string }
variable "domain_name" { type = string }

locals {
  domain = {
    default = var.domain_name
    secondary = "www.${var.domain_name}"
    api = "api.${var.domain_name}"
  }
}

provider "digitalocean" { token = var.digitalocean_token }
provider "docker" { host = "unix:///var/run/docker.sock" }

data "digitalocean_ssh_key" "terraform" { name = var.digitalocean_ssh_key_name }

data "cloudinit_config" "config" {
  gzip = false
  base64_encode = false
  part {
    content_type = "text/cloud-config"
    content = yamlencode({
      package_update = true
      package_upgrade = true
      packages = ["docker.io", "docker-compose"]
    })
  }
}

resource "digitalocean_droplet" "web" {
  image = "debian-13-x64"
  name = "web"
  region = "nyc3"
  size = "s-1vcpu-1gb"
  ssh_keys = [data.digitalocean_ssh_key.terraform.id]
  user_data = data.cloudinit_config.config.rendered
}

resource "digitalocean_domain" "default" {
  name = local.domain.default
  ip_address = digitalocean_droplet.web.ipv4_address
}

resource "digitalocean_domain" "secondary" {
  name = local.domain.secondary
  ip_address = digitalocean_droplet.web.ipv4_address
}

resource "digitalocean_domain" "api" {
  name = local.domain.api
  ip_address = digitalocean_droplet.web.ipv4_address
}

resource "digitalocean_record" "root" {
  domain = digitalocean_domain.default.id
  type = "A"
  name = "@"
  value = digitalocean_droplet.web.ipv4_address
  ttl = 3600
}

output "droplet_ip_address" {
  value= digitalocean_droplet.web.ipv4_address
}
