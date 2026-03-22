# MetaboFlow Phase 1 MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a production-ready MetaboFlow MVP with 50 publication-grade chart templates, multi-page frontend, PDF/Word report export, and user authentication for 5-10 external labs.

**Architecture:** Next.js multi-page frontend → FastAPI backend (JWT auth) → Celery → R workers (xcms/stats/charts) + Python workers (annotation). Chart templates are R scripts sharing a unified Nature-style theme, rendered to SVG/PDF/PNG. Reports use Quarto (PDF) and officer (Word).

**Tech Stack:** Next.js 14 + Tailwind + shadcn/ui, FastAPI + SQLAlchemy + python-jose, R + ggplot2 + ComplexHeatmap + patchwork, Quarto, Docker Compose (10 services)

**Current State:** 4-sample E2E verified (46,862 features, 4,495 significant). 10 Docker services running. Frontend has wizard skeleton. chart-service has 5 basic Python plots.

**Spec Documents:**
- `docs/superpowers/specs/2026-03-21-phase1-mvp-complete-design.md`
- `docs/superpowers/specs/2026-03-21-chart-template-system-design.md`
- `docs/superpowers/specs/2026-03-21-frontend-multipage-architecture-design.md`
- `docs/superpowers/specs/2026-03-21-report-export-system-design.md`
- `docs/superpowers/specs/2026-03-21-user-auth-system-design.md`

---

## File Structure Overview

### New Files to Create

```
packages/backend/app/
├── api/auth.py                          # Auth routes (login/register/refresh)
├── db/models.py                         # Add User, InviteCode models
├── middleware/auth.py                    # JWT middleware + current_user dependency
├── services/auth_service.py             # Auth business logic

packages/frontend/src/
├── app/login/page.tsx                   # Login page
├── app/register/page.tsx                # Register page
├── app/projects/page.tsx                # NEW (replaces existing analyses/page.tsx)
├── app/projects/[id]/page.tsx           # Project overview
├── app/projects/[id]/upload/page.tsx    # Data upload
├── app/projects/[id]/pipeline/page.tsx  # Pipeline designer
├── app/projects/[id]/monitor/page.tsx   # Real-time monitoring
├── app/projects/[id]/results/page.tsx   # Results (5 tabs)
├── app/projects/[id]/report/page.tsx    # Report generation
├── components/pipeline/                  # Pipeline designer components
├── components/auth/                      # Auth components
├── lib/auth.ts                          # JWT token management
├── middleware.ts                         # Next.js auth middleware

packages/engines/chart-r-worker/         # NEW: R chart rendering service
├── Dockerfile
├── entrypoint.R
├── plumber.R                            # HTTP API for chart rendering
├── R/
│   ├── metaboflow_theme.R               # Unified Nature-style theme
│   ├── color_palettes.R                 # Color palettes (colorblind-safe)
│   └── render_template.R               # Template renderer
├── templates/
│   ├── basic/                           # 20 basic R templates
│   └── advanced/                        # 30 advanced R templates
├── interpretations/                     # Chinese + English explanations
│   ├── zh/
│   └── en/
└── registry.json                        # Template registry

packages/engines/report-worker/          # NEW: Report generation service
├── Dockerfile
├── entrypoint.R
├── plumber.R
├── R/
│   ├── render_pdf.R                     # Quarto PDF rendering
│   ├── render_word.R                    # officer Word rendering
│   └── methods_generator.R             # Auto Methods paragraph
├── templates/
│   ├── report.qmd                       # Quarto template
│   ├── report_word_template.docx        # Word template
│   └── methods_templates.yaml           # Methods text per engine
```

### Existing Files to Modify

```
packages/backend/app/
├── db/models.py              # Add User, InviteCode tables
├── db/base.py                # No change needed (PostgreSQL already configured)
├── api/analysis.py           # Add user_id filtering
├── services/analysis_service.py  # Add user_id to create/query
├── tasks/analysis_tasks.py   # Write results back to DB
├── main.py                   # Add auth router, CORS

packages/frontend/src/
├── app/layout.tsx            # Add auth provider
├── lib/api.ts                # Add JWT token headers
├── stores/analysis-store.ts  # Adapt to new API shape

docker-compose.yml            # Add chart-r-worker, report-worker services
```

---

## Task 0: Result Persistence (Quick Fix)

**Goal:** Celery task writes n_features / n_significant / result_files back to DB so API `/result` returns real data.

**Files:**
- Modify: `packages/backend/app/tasks/analysis_tasks.py`
- Modify: `packages/backend/app/services/analysis_service.py`

- [ ] **Step 1: Add `update_result` to analysis_service.py**

`repository.py` already has `update_result(analysis_id, result)` at line 116 using `self._db`.
Add a thin wrapper in `packages/backend/app/services/analysis_service.py`:

```python
def update_result(
    analysis_id: str,
    *,
    n_features: int = 0,
    n_significant: int = 0,
    n_annotated: int = 0,
    n_pathways: int = 0,
    result_files: list[str] | None = None,
    metabodata_path: str | None = None,
) -> None:
    """Write analysis results to DB (called by Celery tasks after each step)."""
    with _session() as repo:
        repo.update_result(analysis_id, {
            "n_features": n_features,
            "n_significant": n_significant,
            "n_annotated": n_annotated,
            "n_pathways": n_pathways,
            "result_files": result_files or [],
            "metabodata_path": metabodata_path,
        })
```

Note: `repo.update_result` already exists in `repository.py:116` and uses `self._db`. Do NOT create a duplicate.

- [ ] **Step 2: Call update_result from Celery tasks**

In `packages/backend/app/tasks/analysis_tasks.py`, after each step completes, add:

After `_run_peak_detection`:
```python
analysis_service.update_result(
    analysis_id,
    n_features=runtime["n_features"],
    metabodata_path=runtime["metabodata_path"],
)
```

After `_run_statistics`:
```python
analysis_service.update_result(
    analysis_id,
    n_significant=runtime["n_significant"],
)
```

- [ ] **Step 3: Rebuild celery-worker and test**

```bash
docker compose build celery-worker && docker compose up -d celery-worker
# Verify with existing completed analysis or create new one
curl -s http://localhost:8000/api/v1/analyses/{id}/result | python3 -m json.tool
# Expected: n_features > 0, n_significant > 0
```

- [ ] **Step 4: Commit**

```bash
git add packages/backend/app/tasks/analysis_tasks.py packages/backend/app/services/analysis_service.py
git commit -m "fix: persist analysis results (n_features/n_significant) to DB from Celery tasks"
```

---

## Task 1: Chart Template Research (4 Agents Parallel)

**Goal:** Research and catalog 50 chart templates (20 basic + 30 advanced) from Nature/Science metabolomics papers (2020-2026), with data source classification (A/B/C/D) and filter sensitivity labels.

**This is a research task, not a coding task.** Launch 4 agents in parallel:

- [ ] **Step 1: Launch 4 research agents in parallel**

Use `Agent` tool with `subagent_type: research-scout` for all 4:

**Agent 1 — Literature Survey Agent:**
Prompt: Search Nature, Science, Nature Methods, Nature Metabolism, Nature Chemical Biology, Analytical Chemistry, and metabolomics journals (2020-2026) for untargeted metabolomics papers. Identify and catalog the 50 most common figure types used. For each figure type, record: name, frequency of occurrence, what it shows, typical data inputs, which paper(s) used it, whether it's basic (single variable) or advanced (multi-variable composite). Output a ranked list of 20 basic (high-frequency, must-have) + 30 advanced (multi-variable composite) chart types. Exclude radar charts.

**Agent 2 — Data Requirements Agent:**
Prompt: For each of the 50 chart types (will receive list from Agent 1), classify data source as A (available in MetaboData HDF5: feature matrix, limma output, annotation results), B (needs new pipeline output from xcms-worker/stats-worker), C (needs raw mzML extraction: EIC, MS2 spectra, TIC), or D (needs external API/library: KEGG coloring, Reactome topology, RDKit). Also mark each chart as "filter-sensitive" (responds to feature p-value/FC filtering) or "global" (uses all data). Output a table with all classifications.

**Agent 3 — PonylabASMS Reference Agent:**
Prompt: Read the PonylabASMS chart system at `/Users/jiajun-agent/pony/ponylabASMS/py-engine/app/visualization/`. Catalog all 29 existing chart specs in CHART_REGISTRY. For each, assess whether it's applicable to MetaboFlow's metabolomics context (vs ponylabASMS's mass spec proteomics context). Note which can be adapted vs which need redesign. Pay attention to data format alignment — PonylabASMS uses PipelineOutput (file scanning), MetaboFlow uses MetaboData HDF5.

**Agent 4 — Color System Agent:**
Prompt: Design a unified MetaboFlow color system for Nature/Science publication-grade figures. Note: scienceplots is a Python package — for R, manually implement equivalent theme based on Nature journal style guidelines (Helvetica/Arial fonts, minimal gridlines, clean axes). Design: (1) a 8-color discrete palette (colorblind-safe, NPG-style), (2) a diverging continuous palette (blue-white-red for heatmaps), (3) a sequential palette (viridis for pathway), (4) semantic colors (up-regulation red, down-regulation blue, significant/non-significant). Output as R code (ggplot2 theme + scale functions) and a color reference card. Reference existing MetaboFlow chart-service base.py at `packages/chart-service/chart_service/plots/base.py` for the current NPG implementation.

- [ ] **Step 2: Consolidate research outputs**

Merge all 4 agent outputs into:
- `packages/engines/chart-r-worker/registry.json` — complete template registry
- `packages/engines/chart-r-worker/R/metaboflow_theme.R` — unified theme
- `packages/engines/chart-r-worker/R/color_palettes.R` — color system
- `docs/chart-template-catalog.md` — full catalog with data source classifications

- [ ] **Step 3: Create chart-r-worker scaffold**

```bash
mkdir -p packages/engines/chart-r-worker/{R,templates/basic,templates/advanced,interpretations/zh,interpretations/en}
```

Write: `packages/engines/chart-r-worker/registry.json` with all 50 templates.
Write: `packages/engines/chart-r-worker/R/metaboflow_theme.R`
Write: `packages/engines/chart-r-worker/R/color_palettes.R`

- [ ] **Step 4: Commit research outputs**

```bash
git add packages/engines/chart-r-worker/ docs/chart-template-catalog.md
git commit -m "research: 50 chart templates cataloged (20 basic + 30 advanced) with data source classification"
```

---

## Task 2: Chart Template Implementation

**Goal:** Implement all 50 R chart templates with unified theme, Chinese/English interpretations, and Plumber API.

**Files:**
- Create: `packages/engines/chart-r-worker/Dockerfile`
- Create: `packages/engines/chart-r-worker/entrypoint.R`
- Create: `packages/engines/chart-r-worker/plumber.R`
- Create: `packages/engines/chart-r-worker/R/render_template.R`
- Create: 50 template `.R` files in `templates/basic/` and `templates/advanced/`
- Create: 100 interpretation `.md` files (50 × zh + en)
- Modify: `docker-compose.yml` — add chart-r-worker service

- [ ] **Step 1: Create Dockerfile**

```dockerfile
FROM rocker/r-ver:4.4.2

RUN apt-get update && apt-get install -y --no-install-recommends \
    libcairo2-dev libxml2-dev libcurl4-openssl-dev libssl-dev \
    libharfbuzz-dev libfribidi-dev libfreetype6-dev libpng-dev \
    libtiff5-dev libjpeg-dev libsodium-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY R/ ./R/
COPY templates/ ./templates/
COPY interpretations/ ./interpretations/
COPY registry.json plumber.R entrypoint.R ./

RUN Rscript -e " \
    options(repos = c(CRAN = 'https://cloud.r-project.org')); \
    if (!requireNamespace('BiocManager', quietly = TRUE)) \
        install.packages('BiocManager'); \
    BiocManager::install(version = '3.19', ask = FALSE, update = FALSE); \
    install.packages(c('plumber', 'jsonlite', 'ggplot2', 'dplyr', 'tidyr', \
        'ggrepel', 'patchwork', 'svglite', 'Cairo', 'scales', 'RColorBrewer', \
        'viridis', 'pheatmap', 'ggridges', 'ggbeeswarm', 'corrplot', \
        'VennDiagram', 'UpSetR', 'ggforce', 'ggsci')); \
    BiocManager::install(c('ComplexHeatmap', 'EnhancedVolcano', 'rhdf5'), \
        ask = FALSE, update = FALSE); \
"

VOLUME ["/data"]
EXPOSE 8008
CMD ["Rscript", "entrypoint.R"]
```

- [ ] **Step 2: Create plumber.R with /render endpoint**

Key endpoints:
- `POST /render` — renders a template by name, returns file paths
- `GET /templates` — returns registry.json
- `GET /templates/{name}/interpretation/{lang}` — returns interpretation text
- `GET /health`

Input: `{ "template_name": "volcano", "metabodata_path": "/data/...", "output_dir": "/data/...", "mzml_dir": "/data/..." (optional, for type C templates), "params": {} }`
Output: `{ "svg": "/data/.../volcano.svg", "pdf": "/data/.../volcano.pdf", "png": "/data/.../volcano.png" }`

- [ ] **Step 3: Implement render_template.R**

Generic template dispatcher:
```r
render_template <- function(template_name, metabodata_path, output_dir, params = list()) {
  source("/app/R/metabodata_bridge.R")
  source("/app/R/metaboflow_theme.R")
  source("/app/R/color_palettes.R")

  # Find template file
  basic_path <- file.path("/app/templates/basic", paste0(template_name, ".R"))
  advanced_path <- file.path("/app/templates/advanced", paste0(template_name, ".R"))
  template_path <- if (file.exists(basic_path)) basic_path else advanced_path
  if (!file.exists(template_path)) stop("Template not found: ", template_name)

  # Source template and call render function
  source(template_path)
  render_fn <- get(paste0("render_", template_name))

  # Read data
  md <- read_metabodata(metabodata_path)

  # Render to all 3 formats
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  base_name <- file.path(output_dir, template_name)

  p <- render_fn(md, params)

  # SVG
  svglite::svglite(paste0(base_name, ".svg"), width = params$width %||% 10, height = params$height %||% 8)
  print(p)
  dev.off()

  # PDF
  cairo_pdf(paste0(base_name, ".pdf"), width = params$width %||% 10, height = params$height %||% 8)
  print(p)
  dev.off()

  # PNG (300 dpi)
  png(paste0(base_name, ".png"), width = (params$width %||% 10) * 300,
      height = (params$height %||% 8) * 300, res = 300)
  print(p)
  dev.off()

  list(svg = paste0(base_name, ".svg"),
       pdf = paste0(base_name, ".pdf"),
       png = paste0(base_name, ".png"))
}
```

- [ ] **Step 4: Implement basic templates (batch — 20 templates)**

Each template is a single `.R` file with a `render_{name}(md, params)` function that returns a ggplot object. The template reads from `md$X`, `md$obs`, `md$var`, `md$layers`, `md$uns` as needed.

Basic templates to implement (exact list from Task 1 research):
1. `volcano_plot.R` — Enhanced volcano (EnhancedVolcano)
2. `pca_score.R` — PCA score plot with confidence ellipses
3. `pca_loading.R` — PCA loading plot
4. `plsda_score.R` — PLS-DA score plot
5. `opls_splot.R` — OPLS-DA S-plot
6. `heatmap_clustered.R` — Hierarchical clustering heatmap (ComplexHeatmap)
7. `correlation_heatmap.R` — Feature correlation matrix
8. `boxplot_top.R` — Top significant features boxplot
9. `violin_plot.R` — Violin + jitter for top features
10. `ma_plot.R` — MA plot (log2FC vs mean expression)
11. `fc_distribution.R` — Fold change distribution histogram
12. `tic_overlay.R` — TIC chromatogram overlay (needs mzML — type C)
13. `bpc_comparison.R` — BPC comparison (type C)
14. `missing_heatmap.R` — Missing value pattern heatmap
15. `cv_distribution.R` — CV distribution plot (QC)
16. `pathway_bubble.R` — Pathway enrichment bubble chart
17. `kegg_colored.R` — KEGG pathway coloring (type D)
18. `annotation_pie.R` — Annotation level distribution pie
19. `chemical_class.R` — Chemical class distribution bar
20. `trend_cluster.R` — Mfuzz trend clustering (type B — needs mfuzz output)

- [ ] **Step 5: Implement advanced templates (batch — 30 templates)**

Advanced templates combine multiple variables in a single figure:
1-10: Multi-panel composites using patchwork
11-20: Nested/overlay plots
21-30: Network, clinical, multi-group comparison plots

(Exact list from Task 1 research output)

- [ ] **Step 6: Write Chinese + English interpretations**

For each of the 50 templates, create:
- `interpretations/zh/{template_name}.md`
- `interpretations/en/{template_name}.md`

Each ~200 words explaining: what the chart shows, how to read it, what to look for, common pitfalls.

- [ ] **Step 7: Add chart-r-worker to docker-compose.yml**

```yaml
  chart-r-worker:
    image: metaboflow/chart-r-worker:0.1.0
    build:
      context: ./packages/engines/chart-r-worker
    volumes:
      - ./data:/data
    expose:
      - "8008"
    healthcheck:
      test: ["CMD", "Rscript", "-e", "httr::GET('http://localhost:8008/health')"]
      interval: 30s
      timeout: 10s
      retries: 3
```

- [ ] **Step 8: Build and test chart-r-worker**

```bash
docker compose build chart-r-worker
docker compose up -d chart-r-worker
# Test with existing metabodata.h5
curl -s -X POST http://localhost:8008/render -H "Content-Type: application/json" \
  -d '{"template_name": "volcano_plot", "metabodata_path": "/data/results/33124e57/metabodata_stats.h5", "output_dir": "/data/results/33124e57/charts"}'
# Verify SVG/PDF/PNG files generated
```

- [ ] **Step 9: Commit**

```bash
git add packages/engines/chart-r-worker/ docker-compose.yml
git commit -m "feat: chart-r-worker with 50 publication-grade R templates + Nature theme"
```

---

## Task 3: User Authentication

**Goal:** Add invite-code registration, email/password login, JWT auth, and data isolation. This is independent of other tasks and can run in parallel.

**Files:**
- Create: `packages/backend/app/api/auth.py`
- Create: `packages/backend/app/middleware/auth.py`
- Create: `packages/backend/app/services/auth_service.py`
- Modify: `packages/backend/app/db/models.py`
- Modify: `packages/backend/app/main.py`
- Create: `packages/frontend/src/app/login/page.tsx`
- Create: `packages/frontend/src/app/register/page.tsx`
- Create: `packages/frontend/src/lib/auth.ts`
- Create: `packages/frontend/src/middleware.ts`

- [ ] **Step 1: Add User and InviteCode DB models (SQLAlchemy 2.0 Mapped[] style)**

In `packages/backend/app/db/models.py`, add (must match existing 2.0 style with `Mapped[]` and `mapped_column`):

```python
from sqlalchemy import Boolean

class User(Base):
    """Registered user."""
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_new_uuid)
    email: Mapped[str] = mapped_column(String(256), unique=True, nullable=False, index=True)
    password_hash: Mapped[str] = mapped_column(String(256), nullable=False)
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )

class InviteCode(Base):
    """Single-use invite code for registration."""
    __tablename__ = "invite_codes"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_new_uuid)
    code: Mapped[str] = mapped_column(String(32), unique=True, nullable=False, index=True)
    used_by: Mapped[Optional[str]] = mapped_column(String(36), ForeignKey("users.id"), nullable=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
```

Add to `Analysis` model:
```python
    user_id: Mapped[Optional[str]] = mapped_column(String(36), ForeignKey("users.id"), nullable=True)
```

- [ ] **Step 1b: Database migration**

The project uses `init_db()` which calls `Base.metadata.create_all()`. For existing databases with data:
```bash
# Option A: If no production data yet (dev), just recreate:
docker compose exec backend python -c "from app.db.base import init_db; init_db()"

# Option B: If data exists, use Alembic:
cd packages/backend
uv run alembic revision --autogenerate -m "add users, invite_codes tables and analysis.user_id"
uv run alembic upgrade head
```

- [ ] **Step 2: Create auth_service.py**

`packages/backend/app/services/auth_service.py`:

```python
"""Authentication service — registration, login, JWT token management."""
import secrets
import uuid
from datetime import datetime, timedelta, UTC

from passlib.context import CryptContext
from jose import jwt, JWTError

from app.config import settings
from app.db.base import SessionLocal
from app.db.models import User, InviteCode

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

SECRET_KEY = settings.secret_key  # Add to config
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE = timedelta(minutes=30)
REFRESH_TOKEN_EXPIRE = timedelta(days=7)


def register(email: str, password: str, invite_code: str) -> User:
    """Register a new user with invite code validation."""
    session = SessionLocal()
    try:
        # Validate invite code
        code = session.query(InviteCode).filter_by(code=invite_code, used_by=None).first()
        if code is None:
            raise ValueError("Invalid or used invite code")
        if datetime.fromisoformat(code.expires_at) < datetime.now(UTC):
            raise ValueError("Invite code expired")

        # Check email uniqueness
        if session.query(User).filter_by(email=email).first():
            raise ValueError("Email already registered")

        # Create user
        user = User(
            id=str(uuid.uuid4()),
            email=email,
            password_hash=pwd_context.hash(password),
            created_at=datetime.now(UTC).isoformat(),
        )
        session.add(user)

        # Mark invite code as used
        code.used_by = user.id
        session.commit()
        session.refresh(user)
        return user
    finally:
        session.close()


def authenticate(email: str, password: str) -> User | None:
    """Verify credentials and return user."""
    session = SessionLocal()
    try:
        user = session.query(User).filter_by(email=email).first()
        if user is None or not pwd_context.verify(password, user.password_hash):
            return None
        return user
    finally:
        session.close()


def create_access_token(user_id: str) -> str:
    data = {"sub": user_id, "exp": datetime.now(UTC) + ACCESS_TOKEN_EXPIRE, "type": "access"}
    return jwt.encode(data, SECRET_KEY, algorithm=ALGORITHM)


def create_refresh_token(user_id: str) -> str:
    data = {"sub": user_id, "exp": datetime.now(UTC) + REFRESH_TOKEN_EXPIRE, "type": "refresh"}
    return jwt.encode(data, SECRET_KEY, algorithm=ALGORITHM)


def verify_token(token: str, token_type: str = "access") -> str | None:
    """Verify JWT and return user_id, or None if invalid."""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != token_type:
            return None
        return payload.get("sub")
    except JWTError:
        return None


def generate_invite_code(days_valid: int = 30) -> str:
    """Generate a new invite code (admin only)."""
    code = secrets.token_urlsafe(16)
    session = SessionLocal()
    try:
        invite = InviteCode(
            id=str(uuid.uuid4()),
            code=code,
            expires_at=(datetime.now(UTC) + timedelta(days=days_valid)).isoformat(),
            created_at=datetime.now(UTC).isoformat(),
        )
        session.add(invite)
        session.commit()
        return code
    finally:
        session.close()
```

- [ ] **Step 3: Create auth middleware**

`packages/backend/app/middleware/auth.py`:

```python
"""JWT authentication dependency for FastAPI."""
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from app.services import auth_service
from app.db.base import SessionLocal
from app.db.models import User

security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> User:
    user_id = auth_service.verify_token(credentials.credentials, "access")
    if user_id is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")

    session = SessionLocal()
    try:
        user = session.query(User).filter_by(id=user_id).first()
        if user is None:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
        return user
    finally:
        session.close()


async def get_admin_user(user: User = Depends(get_current_user)) -> User:
    if not user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin required")
    return user
```

- [ ] **Step 4: Create auth API routes**

`packages/backend/app/api/auth.py`:

```python
"""Authentication API routes."""
from fastapi import APIRouter, HTTPException, Request, Response, Depends
from pydantic import BaseModel, EmailStr

from app.middleware.auth import get_current_user, get_admin_user
from app.services import auth_service
from app.db.models import User

router = APIRouter(prefix="/auth", tags=["auth"])


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str
    invite_code: str

class LoginRequest(BaseModel):
    email: EmailStr
    password: str


@router.post("/register")
async def register(req: RegisterRequest):
    try:
        user = auth_service.register(req.email, req.password, req.invite_code)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    access = auth_service.create_access_token(user.id)
    refresh = auth_service.create_refresh_token(user.id)
    return {"access_token": access, "refresh_token": refresh, "user_id": user.id}


@router.post("/login")
async def login(req: LoginRequest, response: Response):
    user = auth_service.authenticate(req.email, req.password)
    if user is None:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    access = auth_service.create_access_token(user.id)
    refresh = auth_service.create_refresh_token(user.id)
    response.set_cookie("refresh_token", refresh, httponly=True, samesite="lax", max_age=7*86400)
    return {"access_token": access, "user_id": user.id}


@router.post("/refresh")
async def refresh_token(request: Request, response: Response):
    """Refresh access token using httpOnly refresh cookie."""
    refresh = request.cookies.get("refresh_token")
    if not refresh:
        raise HTTPException(status_code=401, detail="No refresh token")
    user_id = auth_service.verify_token(refresh, "refresh")
    if user_id is None:
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    access = auth_service.create_access_token(user_id)
    return {"access_token": access}


@router.post("/invite-codes", dependencies=[Depends(get_admin_user)])
async def create_invite_code(days_valid: int = 30):
    code = auth_service.generate_invite_code(days_valid)
    return {"invite_code": code}


@router.get("/me")
async def get_me(user: User = Depends(get_current_user)):
    return {"user_id": user.id, "email": user.email, "is_admin": user.is_admin}
```

- [ ] **Step 5: Add auth router to main.py + add user_id filtering to analysis routes**

Modify `packages/backend/app/main.py` to include auth router.
Modify `packages/backend/app/api/analysis.py` to accept `user: User = Depends(get_current_user)` and filter by `user_id`.

- [ ] **Step 6: Update analysis_service.py for user_id**

Add `user_id` parameter to `create_analysis()` and `list_analyses()`. Filter queries by user_id.

- [ ] **Step 7: Create frontend login/register pages**

`packages/frontend/src/app/login/page.tsx` and `packages/frontend/src/app/register/page.tsx` with shadcn/ui form components.

- [ ] **Step 8: Create frontend auth system**

**Token flow:** access_token stored in JS memory (React state/context), refresh_token in httpOnly cookie (set by backend `/login`). Frontend uses Bearer header for API calls. When access token expires, auto-refresh via `/auth/refresh` (reads cookie server-side).

`packages/frontend/src/lib/auth.ts`:
```typescript
let accessToken: string | null = null

export const setAccessToken = (token: string | null) => { accessToken = token }
export const getAccessToken = () => accessToken

export async function refreshAccessToken(): Promise<string | null> {
  const res = await fetch('/api/v1/auth/refresh', { method: 'POST', credentials: 'include' })
  if (!res.ok) return null
  const data = await res.json()
  setAccessToken(data.access_token)
  return data.access_token
}
```

`packages/frontend/src/middleware.ts`:
```typescript
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export function middleware(request: NextRequest) {
  // Check for refresh_token cookie (httpOnly, set by backend)
  const hasRefresh = request.cookies.has('refresh_token')
  const isAuthPage = request.nextUrl.pathname.startsWith('/login') || request.nextUrl.pathname.startsWith('/register')
  if (!hasRefresh && !isAuthPage) {
    return NextResponse.redirect(new URL('/login', request.url))
  }
  return NextResponse.next()
}

export const config = { matcher: ['/((?!_next|api|favicon).*)'] }
```

Update `packages/frontend/src/lib/api.ts` to include Bearer header from `getAccessToken()` and auto-refresh on 401.

- [ ] **Step 9: Build, test, commit**

```bash
docker compose build backend celery-worker frontend
docker compose up -d
# Test: register → login → create analysis → verify isolation
git add packages/backend/ packages/frontend/
git commit -m "feat: user authentication with invite codes, JWT, and data isolation"
```

---

## Task 4: Frontend Multi-Page Architecture

**Goal:** Rebuild frontend from wizard-only to multi-page architecture with Pipeline Designer, Monitor, Results (5 tabs), and Report pages.

**Files:**
- Rework: `packages/frontend/src/app/` — new page structure
- Create: Pipeline designer components
- Create: Results tabs components
- Modify: `packages/frontend/src/lib/api.ts`

- [ ] **Step 1: Create project pages scaffold**

Create all page files with basic shells:
- `app/projects/page.tsx` — project list
- `app/projects/[id]/page.tsx` — project overview
- `app/projects/[id]/upload/page.tsx` — file upload
- `app/projects/[id]/pipeline/page.tsx` — pipeline designer
- `app/projects/[id]/monitor/page.tsx` — real-time monitoring
- `app/projects/[id]/results/page.tsx` — results (5 tabs)
- `app/projects/[id]/report/page.tsx` — report generation

- [ ] **Step 2: Implement Pipeline Designer page**

Core component: each analysis step as a card with engine dropdown + parameter panel.
Steps: Peak Detection → Deconvolution → Statistics → Annotation → Pathway
Each step shows: engine selector (dropdown from `/api/v1/engines`), parameter form (from `/api/v1/engines/{name}/params` JSON Schema).

- [ ] **Step 3: Implement Monitor page**

SSE connection to `/api/v1/analyses/{id}/progress/stream`.
Display: step progress bars, current step name, elapsed time, log messages.

- [ ] **Step 4: Implement Results page with 5 tabs**

Tabs: Overview, Charts, Features, Annotation, Pathway.

- **Overview tab**: Summary cards (n_features, n_significant, n_annotated, engine versions, duration).
- **Charts tab**: Grid of rendered chart thumbnails (SVG from chart-r-worker). Click to expand. Download buttons (SVG/PDF/PNG). "Generate" button to trigger batch rendering.
- **Features tab**: Sortable/searchable table (m/z, RT, log2FC, p-value, adj.P). Threshold sliders for p-value and FC → updates "filter-sensitive" charts.
- **Annotation tab**: Annotation results table (compound name, SMILES, match score, MSI level, source library).
- **Pathway tab**: Pathway enrichment results + bubble chart.

- [ ] **Step 5: Implement Report page**

Chart selection checkboxes → "Generate Report" button → format selector (PDF/Word) → SSE progress → download link.

- [ ] **Step 6: Update API client**

`packages/frontend/src/lib/api.ts` — add functions for:
- Chart rendering requests
- Report generation requests
- Auth token headers
- SSE connections

- [ ] **Step 7: Build and screenshot verify**

```bash
docker compose build frontend && docker compose up -d frontend
npx playwright screenshot http://localhost:3005/projects /tmp/projects.png --full-page
npx playwright screenshot http://localhost:3005/login /tmp/login.png --full-page
```

- [ ] **Step 8: Commit**

```bash
git add packages/frontend/
git commit -m "feat: multi-page frontend with pipeline designer, results tabs, and report page"
```

---

## Task 5: Report Export System

**Goal:** Generate PDF (Quarto) and Word (officer) reports with auto Methods paragraphs.

**Files:**
- Create: `packages/engines/report-worker/` — entire service
- Modify: `docker-compose.yml`
- Create: Backend API for report generation

- [ ] **Step 1: Create report-worker scaffold**

```
packages/engines/report-worker/
├── Dockerfile
├── entrypoint.R
├── plumber.R
├── R/
│   ├── render_pdf.R
│   ├── render_word.R
│   ├── methods_generator.R
│   └── metabodata_bridge.R  (copy from xcms-worker)
├── templates/
│   ├── report.qmd
│   ├── report_word_template.docx
│   └── methods_templates.yaml
```

- [ ] **Step 2: Create Dockerfile with Quarto**

Base: `rocker/r-ver:4.4.2` + Quarto CLI + officer package.

```dockerfile
FROM rocker/r-ver:4.4.2

# System deps + Quarto
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcairo2-dev libxml2-dev libcurl4-openssl-dev libssl-dev \
    libsodium-dev wget && \
    ARCH=$(dpkg --print-architecture) && \
    wget -qO /tmp/quarto.deb "https://github.com/quarto-dev/quarto-cli/releases/download/v1.6.40/quarto-1.6.40-linux-${ARCH}.deb" && \
    dpkg -i /tmp/quarto.deb && rm /tmp/quarto.deb && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

RUN Rscript -e " \
    options(repos = c(CRAN = 'https://cloud.r-project.org')); \
    install.packages(c('plumber', 'jsonlite', 'officer', 'flextable', 'knitr', 'rmarkdown')); \
    BiocManager::install('rhdf5', ask = FALSE, update = FALSE); \
"

VOLUME ["/data"]
EXPOSE 8009
CMD ["Rscript", "entrypoint.R"]
```

- [ ] **Step 3: Create methods_templates.yaml**

```yaml
xcms:
  template: >
    Peak detection was performed using XCMS (v{version}, {method} method,
    ppm = {ppm}, peakwidth = [{peakwidth_min}, {peakwidth_max}] s,
    snthresh = {snthresh}).
  params: [version, method, ppm, peakwidth_min, peakwidth_max, snthresh]

camera:
  template: >
    Feature deconvolution was performed using CAMERA (v{version}).
    {n_groups} compound groups were identified from {n_features} features.
  params: [version, n_groups, n_features]

limma:
  template: >
    Statistical analysis was performed using limma (v{version}) with
    Benjamini-Hochberg FDR correction (adjusted p < {alpha},
    |log2FC| > {fc_cut}).
  params: [version, alpha, fc_cut]

matchms:
  template: >
    Metabolite annotation was performed against the MetaboFlow Spectral
    Library (MFSL v{mfsl_version}, {n_compounds} compounds) using matchms
    (v{version}) with {method} similarity ≥ {min_score}.
  params: [version, mfsl_version, n_compounds, method, min_score]
```

- [ ] **Step 4: Create methods_generator.R**

Reads MetaboData HDF5 `uns` provenance data, fills in templates from YAML.

- [ ] **Step 5: Create report.qmd template**

Quarto template with sections: Summary, QC, Features, Statistics, Annotation, Pathway, Methods, Appendix. Embeds PNG charts from chart output directory.

- [ ] **Step 6: Create render_word.R**

Uses officer to create Word document with same sections. Includes editable Methods paragraph.

- [ ] **Step 7: Create plumber.R endpoints**

- `POST /generate` — { metabodata_path, chart_dir, output_dir, format: "pdf"|"word"|"both" }
- `GET /health`

- [ ] **Step 8: Add to docker-compose.yml, build and test**

```bash
docker compose build report-worker && docker compose up -d report-worker
# Test report generation with existing analysis data
curl -s -X POST http://localhost:8009/generate -H "Content-Type: application/json" \
  -d '{"metabodata_path": "/data/results/33124e57/metabodata_stats.h5", "chart_dir": "/data/results/33124e57/charts", "output_dir": "/data/results/33124e57/report", "format": "both"}'
```

- [ ] **Step 9: Wire backend report API**

**Replace** existing `packages/backend/app/api/reports.py` (currently generates HTML reports) with new endpoints that proxy to report-worker via httpx. The existing HTML report endpoints (`/analyses/{id}/report`, `/analyses/{id}/report/download`) will be replaced with PDF/Word generation endpoints. Keep the same URL paths but change response format.

- [ ] **Step 10: Commit**

```bash
git add packages/engines/report-worker/ docker-compose.yml packages/backend/app/api/reports.py
git commit -m "feat: report-worker with Quarto PDF + officer Word + auto Methods generation"
```

---

## Task 6: Integration Testing + Deployment Prep

**Goal:** Full integration test of all components working together. Fix any issues. Prepare for internal testing deployment.

- [ ] **Step 1: Full E2E integration test**

Complete flow: register → login → create project → upload 4 mzML → configure pipeline → start → monitor → view results → generate charts → generate report → download PDF/Word.

```bash
# 1. Generate invite code (admin CLI)
curl -s -X POST http://localhost:8000/api/v1/auth/invite-codes -H "Authorization: Bearer $ADMIN_TOKEN"

# 2. Register
curl -s -X POST http://localhost:8000/api/v1/auth/register -d '{"email":"test@lab.com","password":"test123","invite_code":"..."}'

# 3. Create analysis + upload + start
# ... (same as before but with auth headers)

# 4. Wait for completion

# 5. Generate charts
curl -s -X POST http://localhost:8008/render -d '{"template_name":"volcano_plot",...}'

# 6. Generate report
curl -s -X POST http://localhost:8009/generate -d '{"format":"both",...}'

# 7. Verify all outputs exist
ls data/results/{id}/charts/
ls data/results/{id}/report/
```

- [ ] **Step 2: Frontend screenshot verification**

```bash
npx playwright screenshot http://localhost:3005/login /tmp/login.png --full-page
npx playwright screenshot http://localhost:3005/projects /tmp/projects.png --full-page
# ... verify all pages render correctly
```

- [ ] **Step 3: Fix any integration issues**

Address any errors found during testing.

- [ ] **Step 4: Update PRODUCT.md and HANDOFF.md**

Reflect Phase 1 completion status.

- [ ] **Step 5: Push all changes**

```bash
git push
```

- [ ] **Step 6: Update Phase 1 completion in product-development-plan.md**

```
Phase 1  ████████████████████ 100%
```

---

## Execution Dependencies

```
Task 0 (Result Persistence) ─── no deps, do first ──────────────┐
                                                                  │
Task 1 (Chart Research) ──── no deps, parallel with Task 0/3 ───┤
                                                                  │
Task 3 (User Auth) ────── no deps, parallel with Task 0/1 ──────┤
                                                                  │
Task 2 (Chart Implementation) ── depends on Task 1 output ──────┤
                                                                  │
Task 4 (Frontend) ── depends on Task 2 (charts) + Task 3 (auth)─┤
                                                                  │
Task 5 (Report Export) ── depends on Task 2 (charts) ───────────┤
                                                                  │
Task 6 (Integration) ── depends on ALL above ───────────────────┘
```

**Parallelization strategy:**
- Wave 1: Task 0 + Task 1 + Task 3 (all independent)
- Wave 2: Task 2 (needs Task 1 output)
- Wave 3: Task 4 + Task 5 (both need Task 2, can run in parallel)
- Wave 4: Task 6 (integration)
