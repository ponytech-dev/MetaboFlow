# MetaboFlow Deployment Guide

## Prerequisites

- Oracle Cloud Free Tier account (or any Ubuntu 22.04 server with ≥8GB RAM)
- Domain name pointing to server IP (e.g., ponytech.dev)
- SSH access to server

## Quick Deploy (3 steps)

### Step 1: Setup server (run as root)

```bash
ssh ubuntu@<SERVER_IP>
sudo bash
curl -fsSL https://raw.githubusercontent.com/ponytech-dev/MetaboFlow/main/deploy/setup-server.sh | bash
```

### Step 2: Deploy MetaboFlow (run as ubuntu)

```bash
cd /opt/metaboflow
git clone https://github.com/ponytech-dev/MetaboFlow.git .
export METABOFLOW_DOMAIN=ponytech.dev
export ADMIN_EMAIL=<agent-email>
bash deploy/deploy.sh
```

First build takes 15-30 minutes (R packages compilation).

### Step 3: Setup Nginx + SSL (run as root)

```bash
export METABOFLOW_DOMAIN=ponytech.dev
export ADMIN_EMAIL=<agent-email>
sudo bash deploy/setup-nginx.sh
```

## Access

- Frontend: https://ponytech.dev
- API docs: https://ponytech.dev/docs
- Admin: <agent-email> / MetaboFlow2026! (change after first login)

## Server Requirements

| Scale | RAM | CPU | Disk | Monthly Cost |
|-------|-----|-----|------|-------------|
| 5 labs | 8GB | 4 cores | 100GB | Free (Oracle) |
| 10 labs | 16-24GB | 4 cores | 200GB | Free (Oracle) |
| 20+ labs | 32GB | 8 cores | 500GB | ~$40/mo |

## Maintenance

```bash
# Update to latest version
cd /opt/metaboflow
git pull
docker compose build --parallel
docker compose up -d

# View logs
docker compose logs -f backend
docker compose logs -f xcms-worker

# Check service health
docker compose ps
```
