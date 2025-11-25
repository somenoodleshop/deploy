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
    endpoints = { s3 = "https://sfo3.digitaloceanspaces.com" }
    encrypt = true
    skip_credentials_validation = true
    skip_metadata_api_check = true
    skip_region_validation = true
  }
}

variable "digitalocean_ssh_key_name" { type = string }
variable "digitalocean_token" { type = string }
variable "private_key" { type = string }
variable "public_key" { type = string }
variable "domain_name" { type = string }
variable "github_actor" { type = string }
variable "github_token" { type = string }

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
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y python3 docker.io docker-compose",
      "mkdir app",
      "docker login ghcr.io -u ${var.github_actor} -p ${var.github_token}",
      "docker run -p 80:80 nginxdemos/hello"
    ]
  }
}
