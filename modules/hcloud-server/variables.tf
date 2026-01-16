variable "server_name" {
  description = "Name of the Hetzner Cloud server"
  type        = string
}

variable "server_type" {
  description = "Hetzner Cloud server type (e.g., cpx32, cx22)"
  type        = string
  default     = "cx22"
}

variable "image" {
  description = "Server image to use"
  type        = string
  default     = "docker-ce"
}

variable "location" {
  description = "Hetzner Cloud location (e.g., nbg1, fsn1)"
  type        = string
  default     = "nbg1"
}

variable "ssh_key_name" {
  description = "Name for the SSH key in Hetzner Cloud"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key file"
  type        = string
}

variable "ssh_init_script" {
  description = "Path to SSH initialization/hardening script"
  type        = string
}

variable "custom_setup_commands" {
  description = "Custom setup commands to run after SSH hardening (optional)"
  type        = string
  default     = ""
}

variable "additional_ssh_keys" {
  description = "List of additional SSH public keys to authorize"
  type        = list(string)
  default     = []
}

variable "firewall_ids" {
  description = "List of firewall IDs to apply"
  type        = list(number)
  default     = []
}

variable "primary_ip_name" {
  description = "Name of existing primary IP to attach (optional)"
  type        = string
  default     = ""
}
