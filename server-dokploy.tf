# Dokploy server deployment
# Includes: SSH hardening, UFW firewall, fail2ban, Dokploy installation

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

module "dokploy_server" {
  source = "./modules/hcloud-server"

  server_name          = "eas-v2-prod"
  server_type          = "cpx32"
  image                = "docker-ce"
  location             = "nbg1"
  ssh_key_name         = "dokploy_eas"
  ssh_public_key_path  = "~/.ssh/dokploy/id_eas_v2_prod.pub"
  ssh_private_key_path = "~/.ssh/dokploy/id_eas_v2_prod"
  ssh_init_script      = "./ssh_init.sh"

  # Install Dokploy after SSH hardening
  custom_setup_commands = "curl -sSL https://dokploy.com/install.sh | sh"

  # Optional: Add additional SSH keys
  additional_ssh_keys = []

  # Use existing primary IP
  primary_ip_name = "dokploy-ip"

  # Optional: Apply Hetzner Cloud firewall
  firewall_ids = []
}

output "dokploy_ip" {
  description = "Dokploy server IPv4 address"
  value       = module.dokploy_server.ipv4_address
}

output "dokploy_url" {
  description = "Dokploy UI URL (access via SSH tunnel)"
  value       = "http://localhost:3000 (via: ssh -L 3000:localhost:3000 -p 222 root@${module.dokploy_server.ipv4_address})"
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh -p 222 root@${module.dokploy_server.ipv4_address}"
}
