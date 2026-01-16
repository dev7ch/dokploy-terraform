terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    version = "1.54.0" }
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

resource "hcloud_ssh_key" "dokploy_ssh_key" {
  name       = "dokploy_eas"
  public_key = file(pathexpand("~/.ssh/dokploy/id_eas_v2_prod.pub"))
}

# Add additional SSH keys here if needed
# resource "hcloud_ssh_key" "additional_key_1" {
#   name       = "additional_key_1"
#   public_key = file(pathexpand("~/.ssh/dokploy/id_additional.pub"))
# }

variable "additional_ssh_keys" {
  description = "List of additional SSH public keys to authorize (full key content)"
  type        = list(string)
  default     = []
}

data "hcloud_primary_ip" "dokploy-ip" {
  name = "dokploy-ip"
}

resource "hcloud_server" "dokploy" {
  name         = "eas-v2-prod"
  server_type  = "cx32"
  image        = "docker-ce"
  location     = "nbg1"
  ssh_keys     = [hcloud_ssh_key.dokploy_ssh_key.id]
  firewall_ids = [] # UFW is configured via ssh_init.sh - no Hetzner firewall needed

  public_net {
    ipv4 = data.hcloud_primary_ip.dokploy-ip.id
  }

  # Create directory first
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(pathexpand("~/.ssh/dokploy/id_eas_v2_prod"))
      host        = self.ipv4_address
      port        = 22 # Initial connection uses default port
    }
    inline = [
      "mkdir -p /opt/dokploy"
    ]
  }

  # Copy scripts
  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(pathexpand("~/.ssh/dokploy/id_eas_v2_prod"))
      host        = self.ipv4_address
      port        = 22 # Initial connection uses default port
    }
    source      = "./ssh_init.sh"
    destination = "/opt/dokploy/ssh_init.sh"
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(pathexpand("~/.ssh/dokploy/id_eas_v2_prod"))
      host        = self.ipv4_address
      port        = 22 # Initial connection uses default port
    }

    inline = concat([
      # Add additional SSH keys to authorized_keys if provided
      length(var.additional_ssh_keys) > 0 ? "mkdir -p /root/.ssh" : "echo 'No additional keys'",
      length(var.additional_ssh_keys) > 0 ? "chmod 700 /root/.ssh" : "echo 'No additional keys'",
      ], [
      for key in var.additional_ssh_keys : "echo '${key}' >> /root/.ssh/authorized_keys"
      ], [
      length(var.additional_ssh_keys) > 0 ? "chmod 600 /root/.ssh/authorized_keys" : "echo 'No additional keys'",
      # Run SSH hardening script
      "sh /opt/dokploy/ssh_init.sh",
      "rm -rf /opt/dokploy",
      # Install Dokploy
      "curl -sSL https://dokploy.com/install.sh | sh"
    ])
  }
}
