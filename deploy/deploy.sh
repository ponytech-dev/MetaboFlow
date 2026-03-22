#!/bin/bash
# MetaboFlow Deployment Script
# Run from the MetaboFlow repo root: bash deploy/deploy.sh
set -euo pipefail

DOMAIN="${METABOFLOW_DOMAIN:-metaboflow.ponytech.dev}"
ADMIN_EMAIL="${ADMIN_EMAIL:-jiajunagent@gmail.com}"
SECRET_KEY=$(openssl rand -hex 32)

echo "=== MetaboFlow Deployment ==="
echo "Domain: $DOMAIN"
echo "Admin email: $ADMIN_EMAIL"

# 1. Create production .env
echo ">>> Step 1: Create .env"
cat > .env << EOF
# MetaboFlow Production Environment
FRONTEND_PORT=3005
METABOFLOW_DATABASE_URL=postgresql://metaboflow:metaboflow@postgres:5432/metaboflow
METABOFLOW_REDIS_URL=redis://redis:6379/0
METABOFLOW_CELERY_BROKER_URL=redis://redis:6379/0
METABOFLOW_CELERY_RESULT_BACKEND=redis://redis:6379/1
METABOFLOW_SECRET_KEY=${SECRET_KEY}
METABOFLOW_CORS_ORIGINS=["http://localhost:3005","http://${DOMAIN}","https://${DOMAIN}"]
METABOFLOW_XCMS_WORKER_URL=http://xcms-worker:8001
METABOFLOW_STATS_WORKER_URL=http://stats-worker:8002
METABOFLOW_CHART_SERVICE_URL=http://chart-service:8005
METABOFLOW_ANNOT_WORKER_URL=http://annot-worker:8006
METABOFLOW_SIRIUS_WORKER_URL=http://sirius-worker:8007
METABOFLOW_CHART_R_WORKER_URL=http://chart-r-worker:8008
METABOFLOW_REPORT_WORKER_URL=http://report-worker:8009
POSTGRES_USER=metaboflow
POSTGRES_PASSWORD=metaboflow
POSTGRES_DB=metaboflow
EOF
echo ".env created (SECRET_KEY generated)"

# 2. Build all images
echo ">>> Step 2: Build Docker images (this takes 15-30 minutes first time)"
docker compose build --parallel 2>&1 | tail -20

# 3. Start all services
echo ">>> Step 3: Start services"
docker compose up -d

# 4. Wait for services to be healthy
echo ">>> Step 4: Waiting for services..."
for i in $(seq 1 60); do
    healthy=$(docker compose ps --format json 2>/dev/null | python3 -c "
import sys, json
lines = sys.stdin.read().strip().split('\n')
total = len(lines)
ok = sum(1 for l in lines if 'healthy' in l or 'running' in l.lower())
print(f'{ok}/{total}')
" 2>/dev/null || echo "?/?")
    echo "  [$i/60] Services: $healthy"
    if docker compose ps | grep -q "unhealthy\|starting"; then
        sleep 10
    else
        break
    fi
done

# 5. Create admin user + invite codes
echo ">>> Step 5: Create admin user"
docker compose exec -T backend uv run python3 -c "
from app.db.base import SessionLocal, init_db
from app.db.models import User, InviteCode
from app.services.auth_service import hash_password
import uuid, secrets
from datetime import datetime, timedelta, timezone

init_db()
session = SessionLocal()

# Admin user
existing = session.query(User).filter_by(email='${ADMIN_EMAIL}').first()
if not existing:
    admin = User(id=str(uuid.uuid4()), email='${ADMIN_EMAIL}',
                 password_hash=hash_password('MetaboFlow2026!'),
                 is_admin=True, created_at=datetime.now(timezone.utc))
    session.add(admin)
    print(f'Admin created: ${ADMIN_EMAIL} / MetaboFlow2026!')
else:
    print('Admin already exists')

# Generate 10 invite codes
codes = []
for i in range(10):
    code = secrets.token_urlsafe(16)
    invite = InviteCode(id=str(uuid.uuid4()), code=code,
                        expires_at=datetime.now(timezone.utc) + timedelta(days=90),
                        created_at=datetime.now(timezone.utc))
    session.add(invite)
    codes.append(code)

session.commit()
session.close()

print(f'\n10 invite codes (valid 90 days):')
for i, c in enumerate(codes, 1):
    print(f'  {i:2d}. {c}')
"

# 6. Test health
echo ""
echo ">>> Step 6: Health check"
echo -n "Backend: "
curl -s http://localhost:8000/health | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])" 2>/dev/null || echo "FAIL"
echo -n "Frontend: "
curl -s -o /dev/null -w "%{http_code}" http://localhost:3005/ 2>/dev/null || echo "FAIL"

echo ""
echo "=============================================="
echo "  MetaboFlow deployed successfully!"
echo "=============================================="
echo ""
echo "  Frontend: http://${DOMAIN}:3005"
echo "  API docs: http://${DOMAIN}:8000/docs"
echo ""
echo "  Admin login:"
echo "    Email:    ${ADMIN_EMAIL}"
echo "    Password: MetaboFlow2026!"
echo ""
echo "  Change admin password after first login!"
echo ""
echo "  Next: setup Nginx reverse proxy + SSL"
echo "    bash deploy/setup-nginx.sh"
echo "=============================================="
