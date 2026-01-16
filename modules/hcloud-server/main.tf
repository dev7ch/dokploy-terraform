resource "hcloud_ssh_key" "server_key" {
  name       = var.ssh_key_name
  public_key = file(pathexpand(var.ssh_public_key_path))
}

resource "hcloud_server" "server" {
  name         = var.server_name
  server_type  = var.server_type
  image        = var.image
  location     = var.location
  ssh_keys     = [hcloud_ssh_key.server_key.id]
  firewall_ids = var.firewall_ids

  dynamic "public_net" {
    for_each = var.primary_ip_name != "" ? [1] : []
    content {
      ipv4 = data.hcloud_primary_ip.ip[0].id
    }
  }

  # Create directory for scripts
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(pathexpand(var.ssh_private_key_path))
      host        = self.ipv4_address
      port        = 22
    }
    inline = [
      "mkdir -p /opt/setup"
    ]
  }

  # Copy SSH hardening script
  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(pathexpand(var.ssh_private_key_path))
      host        = self.ipv4_address
      port        = 22
    }
    source      = var.ssh_init_script
    destination = "/opt/setup/ssh_init.sh"
  }

  # Run setup scripts
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(pathexpand(var.ssh_private_key_path))
      host        = self.ipv4_address
      port        = 22
    }

    inline = concat([
      # Add additional SSH keys if provided
      length(var.additional_ssh_keys) > 0 ? "mkdir -p /root/.ssh" : "echo 'No additional keys'",
      length(var.additional_ssh_keys) > 0 ? "chmod 700 /root/.ssh" : "echo 'No additional keys'",
      ], [
      for key in var.additional_ssh_keys : "echo '${key}' >> /root/.ssh/authorized_keys"
      ], [
      length(var.additional_ssh_keys) > 0 ? "chmod 600 /root/.ssh/authorized_keys" : "echo 'No additional keys'",
      # Run SSH hardening
      "sh /opt/setup/ssh_init.sh",
      # Run custom setup if provided
      var.custom_setup_commands != "" ? var.custom_setup_commands : "echo 'No custom setup'",
      # Cleanup
      "rm -rf /opt/setup"
    ])
  }
}

data "hcloud_primary_ip" "ip" {
  count = var.primary_ip_name != "" ? 1 : 0
  name  = var.primary_ip_name
}
