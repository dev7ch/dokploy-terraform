# Hetzner Cloud Server Deployment with Terraform

Modular Terraform configuration for deploying secure Hetzner Cloud servers with automated SSH hardening, UFW firewall, and fail2ban.

## Features

- **Modular Architecture**: Reusable Terraform module for any server deployment
- **Two Deployment Options**:
  - `server-basic.tf`: Basic secure server (SSH hardening only)
  - `server-dokploy.tf`: Server with Dokploy pre-installed
- **Automated Security**:
  - UFW firewall (ports 22, 222, 80, 443 only)
  - SSH hardening (ports 22 + 222, key-based auth, disabled password auth)
  - fail2ban (auto-ban after 10 failed attempts, 2-hour ban)
- **Flexible Configuration**: Support for multiple SSH keys, custom scripts, and existing primary IPs

## Quick Start

### 1. Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) installed
- [Hetzner Cloud](https://www.hetzner.com/) account
- SSH key pair (see below)

### 2. Create SSH Keys

```bash
mkdir -p ~/.ssh/dokploy
ssh-keygen -t ed25519 -C "hcloud-server" -f ~/.ssh/dokploy/id_eas_v2_prod
```

### 3. Set Hetzner API Token

```bash
export TF_VAR_hcloud_token="your-hetzner-api-token"
```

### 4. Choose Deployment Type

#### Option A: Basic Server (No Dokploy)

```bash
# Initialize
terraform init

# Deploy basic server
terraform apply -target=module.basic_server

# Output:
# server_ip = "x.x.x.x"
# ssh_command = "ssh -p 222 root@x.x.x.x"
```

**What's included:**
- SSH hardening (ports 22 + 222)
- UFW firewall
- fail2ban protection
- Docker pre-installed

**Use case:** General-purpose server, custom applications

#### Option B: Dokploy Server

```bash
# Initialize
terraform init

# Deploy Dokploy server
terraform apply -target=module.dokploy_server

# Output:
# dokploy_ip = "x.x.x.x"
# dokploy_url = "http://localhost:3000 (via: ssh -L 3000:localhost:3000 -p 222 root@x.x.x.x)"
# ssh_command = "ssh -p 222 root@x.x.x.x"
```

**What's included:**
- Everything from basic server
- Dokploy PaaS platform
- Docker Swarm initialized

**Use case:** Platform-as-a-Service for deploying applications

## Configuration

### Basic Server (`server-basic.tf`)

Customize these variables in the module block:

```hcl
module "basic_server" {
  source = "./modules/hcloud-server"

  server_name          = "my-server"           # Server name in Hetzner
  server_type          = "cx22"                # Instance type
  image                = "docker-ce"           # OS image
  location             = "nbg1"                # Data center location
  ssh_key_name         = "my_key"              # SSH key name in Hetzner
  ssh_public_key_path  = "~/.ssh/id_ed25519.pub"
  ssh_private_key_path = "~/.ssh/id_ed25519"
  ssh_init_script      = "./ssh_init.sh"      # Security hardening script

  # Optional: Add additional SSH keys
  additional_ssh_keys = [
    "ssh-ed25519 AAAA... user@host"
  ]

  # Optional: Use existing primary IP
  primary_ip_name = ""  # Leave empty for new IP

  # Optional: Apply Hetzner Cloud firewall IDs
  firewall_ids = []
}
```

### Dokploy Server (`server-dokploy.tf`)

Same configuration options plus:

```hcl
  # Custom commands run after SSH hardening
  custom_setup_commands = "curl -sSL https://dokploy.com/install.sh | sh"
```

## Security Configuration

### SSH Access

After deployment, connect using:

```bash
# Port 222 (recommended)
ssh -p 222 root@<server-ip>

# Port 22 (fallback)
ssh -p 22 root@<server-ip>
```

### UFW Firewall Rules

| Port | Protocol | Purpose | Access |
|------|----------|---------|--------|
| 22 | TCP | SSH (fallback) | Allowed |
| 222 | TCP | SSH (primary) | Allowed |
| 80 | TCP | HTTP | Allowed |
| 443 | TCP | HTTPS | Allowed |
| All others | * | Blocked | **Denied** |

**Manage UFW:**
```bash
ufw status verbose              # Check status
ufw allow 3000/tcp              # Open port
ufw delete allow 3000/tcp       # Close port
```

### fail2ban

Automatically protects SSH:
- Max attempts: 10
- Ban duration: 2 hours
- Monitors: ports 22 and 222

**Commands:**
```bash
fail2ban-client status sshd              # Check banned IPs
fail2ban-client set sshd unbanip <IP>    # Unban IP
```

## Accessing Dokploy

Port 3000 is **not exposed** through UFW for security. Access via SSH tunnel:

```bash
# Create SSH tunnel
ssh -L 3000:localhost:3000 -p 222 root@<server-ip>

# Access Dokploy in browser
http://localhost:3000
```

For production (`platform.eori-direkt.de`):
1. Configure reverse proxy in Dokploy (nginx/traefik)
2. Point domain DNS to server IP
3. Enable SSL certificate (built-in Let's Encrypt)

## Module Architecture

```
.
├── modules/
│   └── hcloud-server/          # Reusable server module
│       ├── main.tf             # Server provisioning logic
│       ├── variables.tf        # Input variables
│       └── outputs.tf          # Output values
├── server-basic.tf             # Basic server deployment
├── server-dokploy.tf           # Dokploy server deployment
├── ssh_init.sh                 # SSH hardening script
└── main-dokploy.tf             # Legacy (kept for reference)
```

## Customization Examples

### Add Multiple SSH Keys

```hcl
additional_ssh_keys = [
  "ssh-ed25519 AAAA... alice@laptop",
  "ssh-rsa AAAA... bob@desktop"
]
```

### Use Existing Primary IP

```hcl
primary_ip_name = "my-primary-ip"  # Create in Hetzner Console first
```

### Custom Setup Commands

```hcl
custom_setup_commands = <<-EOF
  apt-get update
  apt-get install -y nginx
  systemctl enable nginx
EOF
```

### Different Server Sizes

```hcl
server_type = "cx11"   # Smallest (2GB RAM, 1 vCPU) - €4.15/mo
server_type = "cx22"   # Small (4GB RAM, 2 vCPU) - €5.83/mo
server_type = "cpx32"  # Large (8GB RAM, 4 vCPU) - €21/mo
```

## Cleanup

```bash
# Destroy specific deployment
terraform destroy -target=module.basic_server
terraform destroy -target=module.dokploy_server

# Destroy everything
terraform destroy
```

## Troubleshooting

### SSH Connection Refused

Both ports 22 and 222 should work. If port 222 fails:
```bash
ssh -p 22 root@<ip> "systemctl restart ssh && ss -tlnp | grep ssh"
```

### UFW Blocking Access

Temporarily allow all:
```bash
ssh -p 22 root@<ip> "ufw disable"
```

### fail2ban Banned Your IP

```bash
ssh -p 22 root@<ip> "fail2ban-client set sshd unbanip $(curl -s ifconfig.me)"
```

## Best Practices

1. **Always use SSH keys** - Never enable password authentication
2. **Use port 222 primarily** - Keep port 22 as emergency fallback
3. **Set up firewall rules** - Configure before deploying sensitive applications
4. **Regular updates** - `apt update && apt upgrade` monthly
5. **Monitor fail2ban** - Check logs regularly for attack attempts

## License

MIT
