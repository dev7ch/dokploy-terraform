# Dokploy Terraform Deployment

With this project you can provision a Hetzner VPS with [Dokploy](https://dokploy.com/) pre-installed using Terraform.

**What is Dokploy?**

An open-source, self-hosted Platform-as-a-Service (PaaS) that simplifies application deployment, database management, and server configuration through a web UI and CLI.

**Why this project?**

By combining Terraform with Dokploy, you get:

- **Infrastructure as Code**: Reproducible server provisioning which you can include in your version control
- **Easy Deployment**: Use Dokploy's UI/CLI to manage your applications after initial setup

Additionally:

- **Server hardening and added security**:
  - **UFW Firewall**: Only ports 222 (SSH), 80 (HTTP), 443 (HTTPS) allowed
  - **SSH Hardening**: Custom port 222, key-based auth only, root login with keys only
  - **fail2ban**: Automatic IP blocking after 3 failed SSH attempts
  - **Minimal Attack Surface**: All other ports denied by default
  - To skip hardening, remove the remote-exec line that runs `ssh_init.sh` in `main.tf`

## Table of Contents

- [Default VPS Configuration](#default-vps-configuration)
- [Prerequisites](#prerequisites)
- [Setup Instructions](#setup-instructions)
- [Security Configuration](#security-configuration)
  - [UFW Firewall](#ufw-firewall-auto-configured)
  - [Hetzner Cloud Firewall](#hetzner-cloud-firewall-optional)
  - [Multiple SSH Keys](#multiple-ssh-keys)
- [Accessing the Server](#accessing-the-server)
- [Cleaning Up](#cleaning-up)

## Default VPS Configuration

The VPS will be provisioned with the following settings (configurable in `main.tf`):

```tf
server_type  = "cpx32"
image        = "docker-ce"
location     = "nbg1"
```

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) installed
- [Hetzner Cloud](https://www.hetzner.com/) account with:
  - Activated account
  - IPv4 primary IP named `dokploy-ip` (create in Console → Primary IPs)
  - [API token](https://docs.hetzner.com/cloud/api/getting-started/generating-api-token/)

## Setup Instructions

### 1. Create SSH Key

Generate SSH keys for server provisioning and access:

```bash
mkdir -p ~/.ssh/dokploy
ssh-keygen -t ed25519 -C "dokploy" -f ~/.ssh/dokploy/id_eas_v2_prod
```

**Note:** The key name must match what's configured in `main.tf` (default: `id_eas_v2_prod`).

### 2. Configure Hetzner API Token

**Recommended (Secure):** Use an environment variable:

```bash
export TF_VAR_hcloud_token="your-api-token-here"
```

**Alternative (Less Secure):** Store it in a file (not recommended for production):

```bash
echo "your-api-token-here" > hetzner-token.txt
```

> **Security Note:** The token file is git-ignored, but using environment variables is more secure. Never commit API tokens to version control.

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Provision the Server

```bash
terraform fmt
terraform validate
terraform apply
```

This will:

- Create a new server on Hetzner Cloud
- Configure UFW firewall (ports 222, 80, 443 only)
- Apply SSH hardening (port 222, key-based auth)
- Install fail2ban for brute-force protection
- Install Dokploy

Upon successful completion, you'll see:

```
Congratulations, Dokploy is installed!
Please go to http://<your-ip>:3000
```

**Note:** Port 3000 is not exposed through UFW. See [Security Configuration](#security-configuration) for access options.

## Security Configuration

### UFW Firewall (Auto-Configured)

UFW is automatically configured during provisioning with these rules:

| Port | Protocol | Purpose | Access |
|------|----------|---------|--------|
| 222 | TCP | SSH | Allowed |
| 80 | TCP | HTTP | Allowed |
| 443 | TCP | HTTPS | Allowed |
| All others | * | Blocked | **Denied** |

**Default Policy:** Deny all incoming, allow all outgoing

**Useful Commands:**
```bash
ufw status verbose              # Check firewall status
ufw allow <port>/tcp            # Open additional port
ufw delete allow <port>/tcp     # Close port
```

**Important:** Port 3000 (Dokploy UI) is **not** exposed through UFW. Access Dokploy via:
- SSH tunnel: `ssh -L 3000:localhost:3000 -p 222 root@your-ip`
- Or add rule: `ufw allow 3000/tcp comment 'Dokploy'`
- **Recommended:** Use reverse proxy (nginx/traefik) on port 443 for `platform.eori-direkt.de`

### fail2ban (Auto-Configured)

Automatically protects SSH:
- Bans after 3 failed login attempts
- Ban duration: 2 hours

**Commands:**
```bash
fail2ban-client status sshd              # Check banned IPs
fail2ban-client set sshd unbanip <IP>    # Unban an IP
```

### Hetzner Cloud Firewall (Optional)

For additional network-level protection, you can add a Hetzner Cloud Firewall:

1. Create firewall in Hetzner Console with same rules (ports 222, 80, 443)
2. Update `main.tf` line 47: `firewall_ids = [your-firewall-id]`

**Note:** UFW (host-level) is sufficient for most use cases. Hetzner Firewall adds redundancy.

### API Token Security

- **Always use environment variables** (`TF_VAR_hcloud_token`) instead of token files when possible
- **Never commit** API tokens, SSH private keys, or Terraform state files to version control
- If you must use `hetzner-token.txt`, ensure it's in `.gitignore` (already configured)
- **Rotate your API token immediately** if it's ever exposed or committed to git

### SSH Key Security

- SSH private keys are stored in `~/.ssh/dokploy/` on your local machine (not in the repository)
- The `ssh_init.sh` script applies security hardening:
  - UFW firewall with minimal open ports (222, 80, 443)
  - SSH on custom port 222, key-based auth only
  - fail2ban for automatic threat blocking
  - Connection limits and timeouts

### Multiple SSH Keys

You can authorize additional SSH keys using the `additional_ssh_keys` variable:

```bash
terraform apply -var='additional_ssh_keys=["ssh-ed25519 AAAA... user@host", "ssh-rsa AAAA... another@host"]'
```

Or create a `terraform.tfvars` file:

```hcl
additional_ssh_keys = [
  "ssh-ed25519 AAAA... user@host",
  "ssh-rsa AAAA... another@host"
]
```

### Terraform State

- Terraform state files (`.tfstate`) may contain sensitive information
- These files are git-ignored by default
- Consider using [Terraform Cloud](https://www.terraform.io/cloud) or encrypted remote state for production

## Accessing the Server

After provisioning:

**SSH Access:**
```bash
ssh -p 222 -i ~/.ssh/dokploy/id_eas_v2_prod root@<server-ip>
```

**Dokploy UI (via SSH tunnel):**
```bash
ssh -L 3000:localhost:3000 -p 222 -i ~/.ssh/dokploy/id_eas_v2_prod root@<server-ip>
# Then access: http://localhost:3000
```

**Production Access (platform.eori-direkt.de):**
Configure a reverse proxy in Dokploy to serve on port 443 with SSL.

## Cleaning Up

To destroy all resources created by Terraform:

```bash
terraform destroy
```

**Warning:** This will permanently delete your server and all data on it.

> **Note:** If there's a problem with cleaning up the resource automatically, make sure to clean up the known hosts on your local machine and SSH key for this project under `Hetzner Console > Security > SSH keys`.
