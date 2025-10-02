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

variable "digitalocean_token" { type = string }

provider "digitalocean" { token = var.digitalocean_token }
provider "docker" { host = "unix:///var/run/docker.sock" }
