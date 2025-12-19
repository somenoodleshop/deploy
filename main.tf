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

resource "digitalocean_droplet" "web" {
  image = "debian-13-x64"
  name = "web"
  region = "nyc3"
  size = "s-1vcpu-1gb"
  ssh_keys = [data.digitalocean_ssh_key.terraform.id]
  connection {
    host = self.ipv4_address
    user = "root"
    type = "ssh"
    private_key = try(file(var.private_key), var.private_key)
    timeout = "2m"
  }

  provisioner "file" {
    content = templatefile("${path.module}/config/traefik.yml.tpl", {
      domain_name = var.domain_name
    })
    destination = "/tmp/traefik.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y python3 docker.io docker-compose",
      "mkdir -p /app/traefik/letsencrypt",
      "mv /tmp/traefik.yml /app/traefik/traefik.yml"
    ]
  }
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
