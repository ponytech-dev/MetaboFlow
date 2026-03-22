"""MetaboFlow FastAPI application."""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import analysis, auth, charts, convert, engines, libraries, projects, reports
from app.config import settings
from app.db.base import init_db


@asynccontextmanager
async def lifespan(app: FastAPI):  # noqa: ARG001
    """Initialise database tables on startup (dev convenience)."""
    init_db()
    yield


app = FastAPI(
    title=settings.app_name,
    version="0.1.0",
    description="Metabolomics engine aggregation platform API",
    lifespan=lifespan,
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routes
app.include_router(auth.router, prefix=settings.api_prefix)
app.include_router(analysis.router, prefix=settings.api_prefix)
app.include_router(engines.router, prefix=settings.api_prefix)
app.include_router(reports.router, prefix=settings.api_prefix)
app.include_router(charts.router, prefix=settings.api_prefix)
app.include_router(projects.router, prefix=settings.api_prefix)
app.include_router(convert.router, prefix=settings.api_prefix)
app.include_router(libraries.router, prefix=settings.api_prefix)


@app.get("/health")
async def health() -> dict:
    return {"status": "ok", "app": settings.app_name}


@app.get("/")
async def root() -> dict:
    return {
        "app": settings.app_name,
        "version": "0.1.0",
        "docs": "/docs",
    }
