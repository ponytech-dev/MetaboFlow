"""Database layer tests using SQLite in-memory.

These tests exercise the ORM models and repository classes directly,
completely independently from the FastAPI app and test_api.py.
"""

from __future__ import annotations

import uuid

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.db.base import Base
from app.db.repository import AnalysisRepository, ProjectRepository


# ── Fixtures ──────────────────────────────────────────────────────────────────


@pytest.fixture(scope="function")
def db_session():
    """Isolated in-memory SQLite session for each test."""
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
    )
    # Import models so they register with Base before create_all
    import app.db.models  # noqa: F401
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    yield session
    session.close()
    Base.metadata.drop_all(engine)
    engine.dispose()


@pytest.fixture
def analysis_repo(db_session):
    return AnalysisRepository(db_session)


@pytest.fixture
def project_repo(db_session):
    return ProjectRepository(db_session)


def _new_id() -> str:
    return str(uuid.uuid4())[:8]


def _sample_config() -> dict:
    return {
        "sample_metadata": [
            {"sample_id": "s1", "group": "control", "batch": "b1", "sample_type": "sample"}
        ]
    }


# ── Analysis CRUD tests ───────────────────────────────────────────────────────


class TestAnalysisCRUD:
    def test_create_analysis_returns_row(self, analysis_repo):
        """Creating an analysis persists it and returns the row."""
        aid = _new_id()
        row = analysis_repo.create(
            analysis_id=aid,
            config=_sample_config(),
            upload_dir="/tmp/uploads/" + aid,
            results_dir="/tmp/results/" + aid,
        )
        assert row.id == aid
        assert row.status == "pending"

    def test_get_by_id_found(self, analysis_repo):
        """get_by_id returns the correct row after creation."""
        aid = _new_id()
        analysis_repo.create(
            analysis_id=aid,
            config=_sample_config(),
            upload_dir="/tmp/uploads/" + aid,
            results_dir="/tmp/results/" + aid,
        )
        fetched = analysis_repo.get_by_id(aid)
        assert fetched is not None
        assert fetched.id == aid

    def test_get_by_id_not_found(self, analysis_repo):
        """get_by_id returns None for a non-existent ID."""
        assert analysis_repo.get_by_id("deadbeef") is None

    def test_update_status(self, analysis_repo):
        """update_status changes the status column."""
        aid = _new_id()
        analysis_repo.create(
            analysis_id=aid,
            config=_sample_config(),
            upload_dir="/tmp/uploads/" + aid,
            results_dir="/tmp/results/" + aid,
        )
        updated = analysis_repo.update_status(aid, "running")
        assert updated is not None
        assert updated.status == "running"

    def test_update_progress_merges_fields(self, analysis_repo):
        """update_progress merges new fields into the existing JSON blob."""
        aid = _new_id()
        analysis_repo.create(
            analysis_id=aid,
            config=_sample_config(),
            upload_dir="/tmp",
            results_dir="/tmp",
        )
        analysis_repo.update_progress(aid, {"current_step": 3, "progress_pct": 42.5})
        data = analysis_repo.get_progress_dict(aid)
        assert data is not None
        assert data["current_step"] == 3
        assert data["progress_pct"] == 42.5

    def test_update_result(self, analysis_repo):
        """update_result stores result metrics in the JSON blob."""
        aid = _new_id()
        analysis_repo.create(
            analysis_id=aid,
            config=_sample_config(),
            upload_dir="/tmp",
            results_dir="/tmp",
        )
        analysis_repo.update_result(aid, {"n_features": 500, "n_significant": 50})
        result = analysis_repo.get_result_dict(aid)
        assert result is not None
        assert result["n_features"] == 500
        assert result["n_significant"] == 50

    def test_list_all_returns_all_rows(self, analysis_repo):
        """list_all returns every persisted analysis."""
        ids = [_new_id() for _ in range(3)]
        for aid in ids:
            analysis_repo.create(
                analysis_id=aid,
                config=_sample_config(),
                upload_dir="/tmp",
                results_dir="/tmp",
            )
        rows = analysis_repo.list_all()
        assert len(rows) == 3

    def test_delete_removes_row(self, analysis_repo):
        """delete removes the row and returns True; second call returns False."""
        aid = _new_id()
        analysis_repo.create(
            analysis_id=aid,
            config=_sample_config(),
            upload_dir="/tmp",
            results_dir="/tmp",
        )
        assert analysis_repo.delete(aid) is True
        assert analysis_repo.get_by_id(aid) is None
        assert analysis_repo.delete(aid) is False

    def test_config_json_round_trip(self, analysis_repo):
        """Config dict stored as JSON is faithfully retrieved."""
        aid = _new_id()
        cfg = _sample_config()
        analysis_repo.create(
            analysis_id=aid,
            config=cfg,
            upload_dir="/tmp",
            results_dir="/tmp",
        )
        retrieved = analysis_repo.get_config_dict(aid)
        assert retrieved is not None
        # The config JSON blob must contain the sample_metadata key
        assert "sample_metadata" in retrieved


# ── Project CRUD tests ────────────────────────────────────────────────────────


class TestProjectCRUD:
    def test_create_project(self, project_repo):
        """Creating a project persists it with the given name."""
        pid = _new_id()
        row = project_repo.create(project_id=pid, name="My Project", description="A test project")
        assert row.id == pid
        assert row.name == "My Project"

    def test_get_project_by_id(self, project_repo):
        """get_by_id retrieves a project after creation."""
        pid = _new_id()
        project_repo.create(project_id=pid, name="Alpha")
        fetched = project_repo.get_by_id(pid)
        assert fetched is not None
        assert fetched.name == "Alpha"

    def test_update_project_name(self, project_repo):
        """Updating a project name is reflected in subsequent fetches."""
        pid = _new_id()
        project_repo.create(project_id=pid, name="Old Name")
        updated = project_repo.update(pid, name="New Name")
        assert updated is not None
        assert updated.name == "New Name"

    def test_list_projects(self, project_repo):
        """list_all returns all created projects."""
        for i in range(4):
            project_repo.create(project_id=_new_id(), name=f"Project {i}")
        assert len(project_repo.list_all()) == 4

    def test_delete_project(self, project_repo):
        """Deleting a project removes it from the database."""
        pid = _new_id()
        project_repo.create(project_id=pid, name="Doomed Project")
        assert project_repo.delete(pid) is True
        assert project_repo.get_by_id(pid) is None


# ── Project–Analysis relationship tests ──────────────────────────────────────


class TestProjectAnalysisRelationship:
    def test_add_analysis_to_project(self, db_session):
        """Linking an analysis to a project creates the join-table row."""
        a_repo = AnalysisRepository(db_session)
        p_repo = ProjectRepository(db_session)

        pid = _new_id()
        aid = _new_id()
        p_repo.create(project_id=pid, name="Proj")
        a_repo.create(analysis_id=aid, config=_sample_config(), upload_dir="/tmp", results_dir="/tmp")

        added = p_repo.add_analysis(pid, aid)
        assert added is True

        linked = p_repo.list_analyses(pid)
        assert len(linked) == 1
        assert linked[0].id == aid

    def test_add_analysis_idempotent(self, db_session):
        """Adding the same analysis–project link twice is idempotent."""
        a_repo = AnalysisRepository(db_session)
        p_repo = ProjectRepository(db_session)

        pid = _new_id()
        aid = _new_id()
        p_repo.create(project_id=pid, name="Proj")
        a_repo.create(analysis_id=aid, config=_sample_config(), upload_dir="/tmp", results_dir="/tmp")

        p_repo.add_analysis(pid, aid)
        second = p_repo.add_analysis(pid, aid)  # must not raise or duplicate
        assert second is False
        assert len(p_repo.list_analyses(pid)) == 1

    def test_remove_analysis_from_project(self, db_session):
        """remove_analysis unlinks an analysis from a project."""
        a_repo = AnalysisRepository(db_session)
        p_repo = ProjectRepository(db_session)

        pid = _new_id()
        aid = _new_id()
        p_repo.create(project_id=pid, name="Proj")
        a_repo.create(analysis_id=aid, config=_sample_config(), upload_dir="/tmp", results_dir="/tmp")

        p_repo.add_analysis(pid, aid)
        removed = p_repo.remove_analysis(pid, aid)
        assert removed is True
        assert len(p_repo.list_analyses(pid)) == 0
