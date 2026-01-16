output "server_id" {
  description = "ID of the created server"
  value       = hcloud_server.server.id
}

output "server_name" {
  description = "Name of the created server"
  value       = hcloud_server.server.name
}

output "ipv4_address" {
  description = "IPv4 address of the server"
  value       = hcloud_server.server.ipv4_address
}

output "ipv6_address" {
  description = "IPv6 address of the server"
  value       = hcloud_server.server.ipv6_address
}

output "ssh_key_id" {
  description = "ID of the SSH key"
  value       = hcloud_ssh_key.server_key.id
}
