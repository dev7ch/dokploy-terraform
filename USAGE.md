# Quick Usage Guide

## File Structure

```
dokploy-terraform/
├── modules/hcloud-server/     # Reusable module
│   ├── main.tf               # Core provisioning logic
│   ├── variables.tf          # Module inputs
│   └── outputs.tf            # Module outputs
├── server-basic.tf           # Deploy basic server (no Dokploy)
├── server-dokploy.tf         # Deploy Dokploy server
├── main-dokploy.tf           # Legacy single-file config
└── ssh_init.sh               # Security hardening script
```

## Deployment Options

### Option 1: Basic Server (Recommended for Custom Apps)

```bash
# Set API token
export TF_VAR_hcloud_token="your-token"

# Initialize Terraform
terraform init

# Deploy basic server only
terraform apply -target=module.basic_server

# Connect
ssh -p 222 root@<ip>
```

**What you get:**
- Secure server with UFW + fail2ban
- Docker pre-installed
- SSH on ports 22 + 222
- No Dokploy (saves resources)

**Cost:** ~€5.83/month (cx22)

### Option 2: Dokploy Server (PaaS Platform)

```bash
# Set API token
export TF_VAR_hcloud_token="your-token"

# Initialize Terraform
terraform init

# Deploy Dokploy server only
terraform apply -target=module.dokploy_server

# Access Dokploy UI via SSH tunnel
ssh -L 3000:localhost:3000 -p 222 root@<ip>
# Open: http://localhost:3000
```

**What you get:**
- Everything from basic server
- Dokploy PaaS platform
- Docker Swarm initialized
- Web UI for app deployment

**Cost:** ~€21/month (cpx32)

### Option 3: Both Servers

```bash
# Deploy both
terraform apply

# You'll get:
# - basic_server (cheaper, custom apps)
# - dokploy_server (PaaS platform)
```

## Quick Customization

### Change Server Size

Edit `server-basic.tf` or `server-dokploy.tf`:

```hcl
server_type = "cx11"   # Smallest - €4.15/mo
server_type = "cx22"   # Small - €5.83/mo (default for basic)
server_type = "cpx32"  # Large - €21/mo (default for Dokploy)
```

### Add SSH Keys

```hcl
additional_ssh_keys = [
  "ssh-ed25519 AAAA... user@laptop"
]
```

### Custom Setup Commands

In `server-basic.tf`:
```hcl
custom_setup_commands = <<-EOF
  apt-get install -y nginx
  systemctl enable nginx
EOF
```

## Common Commands

```bash
# Initialize
terraform init

# Plan changes
terraform plan

# Deploy specific server
terraform apply -target=module.basic_server
terraform apply -target=module.dokploy_server

# Deploy all
terraform apply

# Destroy specific server
terraform destroy -target=module.basic_server

# Destroy all
terraform destroy

# Show outputs
terraform output
```

## SSH Access

```bash
# Using alias (edit ~/.ssh/config)
Host my-server
  HostName <ip>
  Port 222
  User root
  IdentityFile ~/.ssh/dokploy/id_eas_v2_prod
  IdentitiesOnly yes

# Then connect
ssh my-server
```

## Security Notes

- **Port 222** is primary SSH port
- **Port 22** is fallback (emergency access)
- **UFW** allows: 22, 222, 80, 443 only
- **fail2ban** bans after 10 failed attempts
- **Password auth** disabled
- **Root login** SSH keys only

## Accessing Dokploy

Dokploy port 3000 is **NOT** exposed externally.

**Development access:**
```bash
ssh -L 3000:localhost:3000 -p 222 root@<ip>
# Open http://localhost:3000
```

**Production access (platform.eori-direkt.de):**
1. Set up reverse proxy in Dokploy
2. Configure SSL certificate
3. Access via port 443

## Troubleshooting

**SSH port 222 not working?**
```bash
ssh -p 22 root@<ip> "systemctl restart ssh && ss -tlnp | grep ssh"
```

**Got banned by fail2ban?**
```bash
ssh -p 22 root@<ip> "fail2ban-client set sshd unbanip YOUR_IP"
```

**Check UFW status:**
```bash
ssh -p 222 root@<ip> "ufw status verbose"
```
