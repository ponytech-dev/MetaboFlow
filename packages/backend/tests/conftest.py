"""Shared pytest fixtures and session-level setup.

Ensures the SQLite database tables exist before any test that touches the
FastAPI app via TestClient.  The default database_url in Settings points at
'sqlite:///./metaboflow.db', so we simply call init_db() once per session.
"""

from __future__ import annotations

import pytest

from app.db.base import init_db


@pytest.fixture(scope="session", autouse=True)
def ensure_tables():
    """Create all SQLite tables once before the test session starts."""
    init_db()
