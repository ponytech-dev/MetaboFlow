"""MetaboFlow FastAPI application."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import analysis, engines
from app.config import settings

app = FastAPI(
    title=settings.app_name,
    version="0.1.0",
    description="Metabolomics engine aggregation platform API",
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
app.include_router(analysis.router, prefix=settings.api_prefix)
app.include_router(engines.router, prefix=settings.api_prefix)


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
