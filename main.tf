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
}

variable "digitalocean_ssh_key_name" { type = string }
variable "digitalocean_token" { type = string }
variable "private_key" { type = string }
variable "public_key" { type = string }
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
  private_networking = true
  region = "nyc3"
  size = "s-1vcpu-1gb"
  ssh_keys = [data.digitalocean_ssh_key.terraform.id]
  connection {
    host = self.ipv4_address
    user = "root"
    type = "ssh"
    private_key = file(var.private_key)
    timeout = "2m"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y python3 docker.io docker-compose",
      "mkdir app"
    ]
  }
}
