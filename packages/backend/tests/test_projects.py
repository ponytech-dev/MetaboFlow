"""Tests for the projects API and project_service."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services import project_service


@pytest.fixture(autouse=True)
def _clear_projects():
    """Reset in-memory store before each test."""
    project_service._projects.clear()
    yield
    project_service._projects.clear()


@pytest.fixture
def client():
    return TestClient(app)


# ── Create ────────────────────────────────────────────────────────────────────


class TestCreateProject:
    def test_create_returns_201(self, client):
        resp = client.post("/api/v1/projects", json={"name": "Alpha"})
        assert resp.status_code == 201

    def test_create_response_fields(self, client):
        resp = client.post("/api/v1/projects", json={"name": "Beta", "description": "A test project"})
        data = resp.json()
        assert data["name"] == "Beta"
        assert data["description"] == "A test project"
        assert "id" in data
        assert data["analysis_ids"] == []
        assert "created_at" in data
        assert "updated_at" in data

    def test_create_without_description(self, client):
        resp = client.post("/api/v1/projects", json={"name": "Gamma"})
        assert resp.status_code == 201
        assert resp.json()["description"] is None


# ── List ──────────────────────────────────────────────────────────────────────


class TestListProjects:
    def test_list_empty(self, client):
        resp = client.get("/api/v1/projects")
        assert resp.status_code == 200
        assert resp.json() == []

    def test_list_multiple(self, client):
        client.post("/api/v1/projects", json={"name": "P1"})
        client.post("/api/v1/projects", json={"name": "P2"})
        resp = client.get("/api/v1/projects")
        assert resp.status_code == 200
        assert len(resp.json()) == 2


# ── Get ───────────────────────────────────────────────────────────────────────


class TestGetProject:
    def test_get_existing(self, client):
        pid = client.post("/api/v1/projects", json={"name": "Delta"}).json()["id"]
        resp = client.get(f"/api/v1/projects/{pid}")
        assert resp.status_code == 200
        assert resp.json()["name"] == "Delta"

    def test_get_not_found(self, client):
        resp = client.get("/api/v1/projects/nonexistent")
        assert resp.status_code == 404


# ── Update ────────────────────────────────────────────────────────────────────


class TestUpdateProject:
    def test_update_name(self, client):
        pid = client.post("/api/v1/projects", json={"name": "OldName"}).json()["id"]
        resp = client.put(f"/api/v1/projects/{pid}", json={"name": "NewName"})
        assert resp.status_code == 200
        assert resp.json()["name"] == "NewName"

    def test_update_description(self, client):
        pid = client.post("/api/v1/projects", json={"name": "Proj"}).json()["id"]
        resp = client.put(f"/api/v1/projects/{pid}", json={"description": "Updated desc"})
        assert resp.status_code == 200
        assert resp.json()["description"] == "Updated desc"

    def test_update_not_found(self, client):
        resp = client.put("/api/v1/projects/missing", json={"name": "X"})
        assert resp.status_code == 404


# ── Delete ────────────────────────────────────────────────────────────────────


class TestDeleteProject:
    def test_delete_existing(self, client):
        pid = client.post("/api/v1/projects", json={"name": "ToDelete"}).json()["id"]
        resp = client.delete(f"/api/v1/projects/{pid}")
        assert resp.status_code == 204
        # confirm gone
        assert client.get(f"/api/v1/projects/{pid}").status_code == 404

    def test_delete_not_found(self, client):
        resp = client.delete("/api/v1/projects/ghost")
        assert resp.status_code == 404


# ── Analyses association ──────────────────────────────────────────────────────


class TestProjectAnalyses:
    def test_add_analysis(self, client):
        pid = client.post("/api/v1/projects", json={"name": "WithAnalysis"}).json()["id"]
        resp = client.post(f"/api/v1/projects/{pid}/analyses/abc123")
        assert resp.status_code == 200
        assert "abc123" in resp.json()["analysis_ids"]

    def test_add_analysis_idempotent(self, client):
        """Adding the same analysis twice should not duplicate it."""
        pid = client.post("/api/v1/projects", json={"name": "Idem"}).json()["id"]
        client.post(f"/api/v1/projects/{pid}/analyses/abc123")
        client.post(f"/api/v1/projects/{pid}/analyses/abc123")
        data = client.get(f"/api/v1/projects/{pid}").json()
        assert data["analysis_ids"].count("abc123") == 1

    def test_remove_analysis(self, client):
        pid = client.post("/api/v1/projects", json={"name": "Remove"}).json()["id"]
        client.post(f"/api/v1/projects/{pid}/analyses/xyz")
        resp = client.delete(f"/api/v1/projects/{pid}/analyses/xyz")
        assert resp.status_code == 200
        assert "xyz" not in resp.json()["analysis_ids"]

    def test_add_analysis_project_not_found(self, client):
        resp = client.post("/api/v1/projects/nope/analyses/abc")
        assert resp.status_code == 404

    def test_remove_analysis_project_not_found(self, client):
        resp = client.delete("/api/v1/projects/nope/analyses/abc")
        assert resp.status_code == 404
