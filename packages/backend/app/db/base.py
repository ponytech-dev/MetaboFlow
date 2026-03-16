"""SQLAlchemy engine, session factory, and declarative base."""

from __future__ import annotations

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from app.config import settings


def _build_url(raw_url: str) -> str:
    """Normalise SQLite URLs; leave everything else untouched."""
    # SQLite in-memory used by tests passes 'sqlite://' or 'sqlite:///...'
    # Regular postgres/psycopg2 URLs are used as-is.
    return raw_url


engine = create_engine(
    _build_url(settings.database_url),
    # SQLite needs this for multi-threaded TestClient use
    connect_args={"check_same_thread": False} if settings.database_url.startswith("sqlite") else {},
    echo=settings.debug,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    """Shared declarative base for all ORM models."""
    pass


def get_db():
    """FastAPI dependency: yields a DB session and closes it afterwards."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db() -> None:
    """Create all tables (used during development startup)."""
    # Import models so they register with Base metadata before create_all
    from app.db import models as _  # noqa: F401
    Base.metadata.create_all(bind=engine)
