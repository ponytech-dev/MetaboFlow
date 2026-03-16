"""Tests for the FastAPI backend API."""

import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture
def client():
    return TestClient(app)


class TestHealthCheck:
    def test_health(self, client):
        resp = client.get("/health")
        assert resp.status_code == 200
        assert resp.json()["status"] == "ok"

    def test_root(self, client):
        resp = client.get("/")
        assert resp.status_code == 200
        assert "MetaboFlow" in resp.json()["app"]


class TestEnginesAPI:
    def test_list_engines(self, client):
        resp = client.get("/api/v1/engines")
        assert resp.status_code == 200
        engines = resp.json()
        assert len(engines) >= 2
        names = [e["name"] for e in engines]
        assert "xcms" in names
        assert "stats" in names

    def test_get_xcms_params(self, client):
        resp = client.get("/api/v1/engines/xcms/params")
        assert resp.status_code == 200
        data = resp.json()
        assert data["engine"] == "xcms"
        assert "ppm" in data["defaults"]
        assert "schema" in data

    def test_get_unknown_engine(self, client):
        resp = client.get("/api/v1/engines/nonexistent/params")
        assert resp.status_code == 404


class TestAnalysisAPI:
    def _create_analysis(self, client):
        config = {
            "sample_metadata": [
                {"sample_id": "s1", "group": "control", "batch": "b1", "sample_type": "sample"},
                {"sample_id": "s2", "group": "treatment", "batch": "b1", "sample_type": "sample"},
            ],
        }
        resp = client.post("/api/v1/analyses", json=config)
        assert resp.status_code == 200
        return resp.json()["analysis_id"]

    def test_create_analysis(self, client):
        aid = self._create_analysis(client)
        assert len(aid) == 8

    def test_get_progress(self, client):
        aid = self._create_analysis(client)
        resp = client.get(f"/api/v1/analyses/{aid}/progress")
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "pending"
        assert data["total_steps"] == 7

    def test_get_result(self, client):
        aid = self._create_analysis(client)
        resp = client.get(f"/api/v1/analyses/{aid}/result")
        assert resp.status_code == 200

    def test_list_analyses(self, client):
        self._create_analysis(client)
        resp = client.get("/api/v1/analyses")
        assert resp.status_code == 200
        assert len(resp.json()) >= 1

    def test_not_found(self, client):
        resp = client.get("/api/v1/analyses/nonexistent/progress")
        assert resp.status_code == 404


class TestEngineAdapters:
    def test_xcms_validation_valid(self):
        from app.engine.xcms_adapter import XCMSAdapter

        adapter = XCMSAdapter()
        result = adapter.validate_params({"ppm": 15, "peakwidth": [5, 30], "noise": 500, "min_fraction": 0.5})
        assert result.is_valid

    def test_xcms_validation_invalid_ppm(self):
        from app.engine.xcms_adapter import XCMSAdapter

        adapter = XCMSAdapter()
        result = adapter.validate_params({"ppm": 200})
        assert not result.is_valid
        assert any("ppm" in e for e in result.errors)

    def test_xcms_validation_invalid_peakwidth(self):
        from app.engine.xcms_adapter import XCMSAdapter

        adapter = XCMSAdapter()
        result = adapter.validate_params({"peakwidth": [30, 5]})
        assert not result.is_valid

    def test_stats_validation_valid(self):
        from app.engine.stats_adapter import StatsAdapter

        adapter = StatsAdapter()
        result = adapter.validate_params({"fc_cutoff": 1.5, "p_value_cutoff": 0.05})
        assert result.is_valid

    def test_stats_validation_invalid(self):
        from app.engine.stats_adapter import StatsAdapter

        adapter = StatsAdapter()
        result = adapter.validate_params({"fc_cutoff": -1})
        assert not result.is_valid

    def test_engine_registry(self):
        from app.engine.registry import engine_registry

        engines = engine_registry.list_engines()
        assert len(engines) >= 2
