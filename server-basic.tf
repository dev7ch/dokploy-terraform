# Basic server deployment without Dokploy
# Includes: SSH hardening, UFW firewall, fail2ban

terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.54.0"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token != "" ? var.hcloud_token : try(trimspace(file("hetzner-token.txt")), "")
}

variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  default     = ""
  sensitive   = true
}

module "basic_server" {
  source = "./modules/hcloud-server"

  server_name          = "basic-server"
  server_type          = "cx22"  # Smaller, cheaper instance
  image                = "docker-ce"
  location             = "nbg1"
  ssh_key_name         = "basic_server_key"
  ssh_public_key_path  = "~/.ssh/dokploy/id_eas_v2_prod.pub"
  ssh_private_key_path = "~/.ssh/dokploy/id_eas_v2_prod"
  ssh_init_script      = "./ssh_init.sh"

  # Optional: Add additional SSH keys
  additional_ssh_keys = []

  # Optional: Use existing primary IP
  primary_ip_name = ""

  # Optional: Apply Hetzner Cloud firewall
  firewall_ids = []
}

output "server_ip" {
  description = "Server IPv4 address"
  value       = module.basic_server.ipv4_address
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh -p 222 root@${module.basic_server.ipv4_address}"
}
