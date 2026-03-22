#!/bin/bash
# MetaboFlow Server Setup Script
# Target: Oracle Cloud Free Tier (ARM/aarch64, Ubuntu 22.04)
# Run as root or with sudo
set -euo pipefail

echo "=== MetaboFlow Server Setup ==="
echo "Target: Oracle Cloud Free Tier (4 ARM cores, 24GB RAM, 200GB disk)"

# 1. System update
echo ">>> Step 1: System update"
apt-get update && apt-get upgrade -y

# 2. Install Docker
echo ">>> Step 2: Install Docker"
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ubuntu  # default Oracle Cloud user
    echo "Docker installed. You may need to re-login for group changes."
else
    echo "Docker already installed"
fi

# 3. Install Docker Compose plugin
echo ">>> Step 3: Install Docker Compose"
if ! docker compose version &>/dev/null; then
    apt-get install -y docker-compose-plugin
else
    echo "Docker Compose already installed"
fi

# 4. Install git
echo ">>> Step 4: Install Git"
apt-get install -y git

# 5. Configure firewall (Oracle Cloud uses iptables by default)
echo ">>> Step 5: Configure firewall"
# Open ports: 80 (HTTP), 443 (HTTPS), 8000 (API), 3005 (frontend)
iptables -I INPUT -p tcp --dport 80 -j ACCEPT
iptables -I INPUT -p tcp --dport 443 -j ACCEPT
iptables -I INPUT -p tcp --dport 8000 -j ACCEPT
iptables -I INPUT -p tcp --dport 3005 -j ACCEPT
# Save rules
apt-get install -y iptables-persistent
netfilter-persistent save

# 6. Setup swap (helpful for R package compilation)
echo ">>> Step 6: Setup swap (4GB)"
if [ ! -f /swapfile ]; then
    fallocate -l 4G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    echo "Swap configured"
else
    echo "Swap already exists"
fi

# 7. Create app directory
echo ">>> Step 7: Create app directory"
mkdir -p /opt/metaboflow
chown ubuntu:ubuntu /opt/metaboflow

echo ""
echo "=== Server setup complete ==="
echo "Next steps:"
echo "  1. SSH as 'ubuntu' user"
echo "  2. cd /opt/metaboflow"
echo "  3. git clone https://github.com/ponytech-dev/MetaboFlow.git ."
echo "  4. bash deploy/deploy.sh"
