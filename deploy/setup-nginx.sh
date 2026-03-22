#!/bin/bash
# Setup Nginx reverse proxy + Let's Encrypt SSL for MetaboFlow
# Run as root or with sudo
set -euo pipefail

DOMAIN="${METABOFLOW_DOMAIN:-ponytech.dev}"
ADMIN_EMAIL="${ADMIN_EMAIL:-jiajunagent@gmail.com}"

echo "=== Nginx + SSL Setup ==="
echo "Domain: $DOMAIN"

# 1. Install Nginx + Certbot
echo ">>> Step 1: Install Nginx + Certbot"
apt-get install -y nginx certbot python3-certbot-nginx

# 2. Create Nginx config
echo ">>> Step 2: Configure Nginx"
cat > /etc/nginx/sites-available/metaboflow << NGINX
server {
    listen 80;
    server_name ${DOMAIN};

    # Frontend
    location / {
        proxy_pass http://127.0.0.1:3005;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # Backend API
    location /api/ {
        proxy_pass http://127.0.0.1:8000/api/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 3600;  # Long timeout for analysis pipelines
    }

    # Backend health + docs
    location /health {
        proxy_pass http://127.0.0.1:8000/health;
    }
    location /docs {
        proxy_pass http://127.0.0.1:8000/docs;
    }
    location /openapi.json {
        proxy_pass http://127.0.0.1:8000/openapi.json;
    }

    # SSE (Server-Sent Events) — needs special proxy config
    location ~ /api/v1/analyses/.*/progress/stream {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Connection '';
        proxy_set_header Cache-Control 'no-cache';
        proxy_set_header X-Accel-Buffering 'no';
        proxy_buffering off;
        chunked_transfer_encoding off;
        proxy_read_timeout 86400;
    }

    # File upload size (mzML files can be 200MB+)
    client_max_body_size 500M;
}
NGINX

ln -sf /etc/nginx/sites-available/metaboflow /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test and reload
nginx -t && systemctl reload nginx

# 3. SSL Certificate
echo ">>> Step 3: SSL Certificate (Let's Encrypt)"
echo "Make sure DNS for ${DOMAIN} points to this server's IP first!"
echo ""
read -p "DNS configured? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    certbot --nginx -d "${DOMAIN}" --non-interactive --agree-tos -m "${ADMIN_EMAIL}"
    echo "SSL certificate installed!"
    echo ""
    echo "MetaboFlow is now available at:"
    echo "  https://${DOMAIN}"
else
    echo "Skipping SSL. Configure DNS first, then run:"
    echo "  certbot --nginx -d ${DOMAIN} --agree-tos -m ${ADMIN_EMAIL}"
    echo ""
    echo "MetaboFlow is available at:"
    echo "  http://${DOMAIN}"
fi

# 4. Auto-renewal
echo ">>> Step 4: Certbot auto-renewal"
systemctl enable certbot.timer
echo "SSL auto-renewal enabled"
