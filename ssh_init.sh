#!/bin/bash
ssh_init() {
    echo "Starting security hardening..."

    # DON'T modify sshd_config yet - keep SSH working
    # Just add port 222 alongside port 22

    # Backup original sshd_config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

    # Add port 222 if not already present, keep everything else default
    if ! grep -q "^Port 222" /etc/ssh/sshd_config; then
        sed -i '/#Port 22/a Port 222' /etc/ssh/sshd_config
        sed -i 's/#Port 22/Port 22/' /etc/ssh/sshd_config
    fi

    # Disable password auth but keep pubkey and PAM
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

    # Set MaxAuthTries to 10
    if grep -q "^MaxAuthTries" /etc/ssh/sshd_config; then
        sed -i 's/^MaxAuthTries.*/MaxAuthTries 10/' /etc/ssh/sshd_config
    else
        echo "MaxAuthTries 10" >> /etc/ssh/sshd_config
    fi

    # Configure UFW firewall
    echo "Configuring UFW firewall..."

    # Install UFW if not present
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ufw > /dev/null 2>&1

    # Reset UFW to default state
    ufw --force reset > /dev/null

    # Set default policies
    ufw default deny incoming
    ufw default allow outgoing

    # Allow SSH on both ports
    ufw allow 22/tcp comment 'SSH-default'
    ufw allow 222/tcp comment 'SSH'

    # Allow HTTP and HTTPS
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'

    # Enable UFW
    ufw --force enable

    echo "UFW configured: Ports 22, 222 (SSH), 80 (HTTP), and 443 (HTTPS) open"

    # Install and configure fail2ban
    echo "Installing fail2ban..."
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq fail2ban > /dev/null

    # Create fail2ban jail configuration for both SSH ports
    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 7200
maxretry = 5
findtime = 600
banaction = iptables-multiport
destemail = root@localhost
sender = root@localhost

[sshd]
enabled = true
port = 22,222
filter = sshd
logpath = /var/log/auth.log
maxretry = 10
bantime = 7200
EOF

    # Enable and start fail2ban
    systemctl enable fail2ban > /dev/null 2>&1
    systemctl start fail2ban

    # Fix systemd socket issue - disable socket, enable service for both ports
    systemctl disable ssh.socket > /dev/null 2>&1 || true
    systemctl stop ssh.socket > /dev/null 2>&1 || true
    systemctl enable ssh.service > /dev/null 2>&1
    systemctl restart ssh.service

    echo "Security hardening complete: SSH (ports 22 + 222), UFW, and fail2ban configured"
}

ssh_init