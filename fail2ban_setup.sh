#!/bin/bash

# Install fail2ban
apt-get update
apt-get install -y fail2ban

# Create fail2ban jail configuration for SSH on port 222
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
# Ban hosts for 1 hour (3600 seconds)
bantime = 3600
# 5 attempts before ban
maxretry = 5
# Time window for attempts (10 minutes)
findtime = 600
# Ban action - use iptables
banaction = iptables-multiport
# Send email alerts (optional - configure if needed)
destemail = root@localhost
sender = root@localhost
# Action: ban and send email
action = %(action_mw)s

[sshd]
enabled = true
port = 222
filter = sshd
logpath = /var/log/auth.log
maxretry = 20
# Ban for 0.5 hours on SSH
bantime = 1800
EOF

# Start and enable fail2ban
systemctl enable fail2ban
systemctl start fail2ban

echo "fail2ban installed and configured"
