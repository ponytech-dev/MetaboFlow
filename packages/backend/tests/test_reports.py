"""Tests for the report generation module."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services import report_service


@pytest.fixture
def client():
    return TestClient(app)


# ── Helpers ───────────────────────────────────────────────────────────────────

def _create_analysis(client: TestClient) -> str:
    """Create a minimal analysis and return its ID."""
    config = {
        "sample_metadata": [
            {"sample_id": "s1", "group": "control",   "batch": "b1", "sample_type": "sample"},
            {"sample_id": "s2", "group": "treatment",  "batch": "b1", "sample_type": "sample"},
            {"sample_id": "qc1", "group": "qc",        "batch": "b1", "sample_type": "qc"},
        ],
        "peak_detection": {
            "engine": "xcms",
            "ppm": 10.0,
            "peakwidth_min": 5.0,
            "peakwidth_max": 30.0,
            "snthresh": 5.0,
            "noise": 500.0,
            "min_fraction": 0.5,
        },
        "qc": {"batch_correction": "serrf"},
    }
    resp = client.post("/api/v1/analyses", json=config)
    assert resp.status_code == 200
    return resp.json()["analysis_id"]


_SAMPLE_PROVENANCE = {
    "created_at": "2024-01-15T10:00:00+00:00",
    "steps": [
        {
            "step": "peak_detection",
            "engine": "xcms",
            "engine_version": "3.22.0",
            "params": {"ppm": 15, "peakwidth_min": 5, "peakwidth_max": 30, "snthresh": 5},
            "timestamp": "2024-01-15T10:01:00+00:00",
        },
        {
            "step": "batch_correction",
            "engine": "serrf",
            "engine_version": "1.0.0",
            "params": {"method": "serrf"},
            "timestamp": "2024-01-15T10:05:00+00:00",
        },
        {
            "step": "statistical_analysis",
            "engine": "metaboanalyst",
            "engine_version": "5.0",
            "params": {
                "analysis_type": "differential",
                "fc_cutoff": 1.5,
                "p_value_cutoff": 0.05,
                "fdr_method": "BH",
            },
            "timestamp": "2024-01-15T10:10:00+00:00",
        },
    ],
}


# ── Unit tests: Methods paragraph ─────────────────────────────────────────────

class TestMethodsParagraphGeneration:
    def test_methods_contains_engine_name(self):
        """XCMS step should produce 'XCMS3' in the methods text."""
        para = report_service.generate_methods_paragraph(_SAMPLE_PROVENANCE)
        assert "XCMS3" in para

    def test_methods_contains_version(self):
        """Engine version numbers must appear in the output."""
        para = report_service.generate_methods_paragraph(_SAMPLE_PROVENANCE)
        assert "3.22.0" in para

    def test_methods_contains_all_steps(self):
        """All three provenance steps should produce a sentence each."""
        para = report_service.generate_methods_paragraph(_SAMPLE_PROVENANCE)
        assert "Peak detection" in para
        assert "Batch effect correction" in para
        assert "Statistical analysis" in para

    def test_methods_empty_provenance(self):
        """Empty provenance must return an empty string, not raise."""
        result = report_service.generate_methods_paragraph({})
        assert result == ""

    def test_methods_no_steps(self):
        """Provenance with 'steps': [] must return an empty string."""
        result = report_service.generate_methods_paragraph({"created_at": "2024-01-01", "steps": []})
        assert result == ""

    def test_methods_unknown_engine_falls_back(self):
        """An unknown engine key should still appear verbatim (no KeyError)."""
        prov = {
            "steps": [
                {
                    "step": "peak_detection",
                    "engine": "my_custom_engine",
                    "engine_version": "",
                    "params": {"ppm": 5},
                    "timestamp": "2024-01-01T00:00:00+00:00",
                }
            ]
        }
        para = report_service.generate_methods_paragraph(prov)
        assert "my_custom_engine" in para

    def test_methods_params_included(self):
        """Key parameters from the provenance must appear in the methods text."""
        para = report_service.generate_methods_paragraph(_SAMPLE_PROVENANCE)
        # ppm parameter from peak_detection step
        assert "ppm" in para


# ── Unit tests: HTML report ───────────────────────────────────────────────────

class TestHTMLReportGeneration:
    def test_report_contains_analysis_id(self, client):
        aid = _create_analysis(client)
        html = report_service.generate_report(aid)
        assert aid in html

    def test_report_contains_all_section_headings(self, client):
        aid = _create_analysis(client)
        html = report_service.generate_report(aid)
        for heading in [
            "Analysis Configuration",
            "Sample Summary",
            "Results Overview",
            "Methods",
            "Provenance Chain",
        ]:
            assert heading in html, f"Missing section: {heading}"

    def test_report_contains_engine(self, client):
        """The configured engine (xcms) must appear in the report."""
        aid = _create_analysis(client)
        html = report_service.generate_report(aid)
        assert "XCMS" in html.upper()

    def test_report_contains_footer(self, client):
        aid = _create_analysis(client)
        html = report_service.generate_report(aid)
        assert "Generated by MetaboFlow v0.1.0" in html

    def test_report_no_charts_excluded(self, client):
        """When include_charts=False, chart placeholder divs must be absent."""
        aid = _create_analysis(client)
        html = report_service.generate_report(aid, include_charts=False)
        # CSS class definition is always present; check for actual div elements
        assert '<div class="chart-placeholder">' not in html

    def test_report_charts_included_by_default(self, client):
        """Default call (include_charts=True) must contain chart placeholder divs."""
        aid = _create_analysis(client)
        html = report_service.generate_report(aid)
        assert '<div class="chart-placeholder">' in html

    def test_report_unknown_analysis_raises(self, client):
        """Requesting a report for a non-existent analysis must raise KeyError."""
        # Ensure DB is initialised by touching the client fixture
        with pytest.raises(KeyError):
            report_service.generate_report("00000000")

    def test_report_sample_count_in_html(self, client):
        """The number of samples must appear in the report HTML."""
        aid = _create_analysis(client)
        html = report_service.generate_report(aid)
        # 3 samples were registered (including 1 QC)
        assert ">3<" in html or "3 " in html or ">3 " in html or "3</td>" in html


# ── API endpoint tests ────────────────────────────────────────────────────────

class TestReportAPI:
    def test_report_endpoint_returns_html(self, client):
        aid = _create_analysis(client)
        resp = client.get(f"/api/v1/analyses/{aid}/report")
        assert resp.status_code == 200
        assert "text/html" in resp.headers["content-type"]

    def test_report_endpoint_html_has_sections(self, client):
        aid = _create_analysis(client)
        resp = client.get(f"/api/v1/analyses/{aid}/report")
        html = resp.text
        assert "Analysis Configuration" in html
        assert "Sample Summary" in html
        assert "Methods" in html

    def test_report_endpoint_404_for_missing(self, client):
        resp = client.get("/api/v1/analyses/nonexistent/report")
        assert resp.status_code == 404

    def test_report_download_endpoint(self, client):
        aid = _create_analysis(client)
        resp = client.get(f"/api/v1/analyses/{aid}/report/download")
        assert resp.status_code == 200
        assert "attachment" in resp.headers.get("content-disposition", "")
        assert ".html" in resp.headers.get("content-disposition", "")

    def test_report_download_404_for_missing(self, client):
        resp = client.get("/api/v1/analyses/nonexistent/report/download")
        assert resp.status_code == 404

    def test_report_no_charts_query_param(self, client):
        aid = _create_analysis(client)
        resp = client.get(f"/api/v1/analyses/{aid}/report?include_charts=false")
        assert resp.status_code == 200
        assert '<div class="chart-placeholder">' not in resp.text


class TestMethodsAPI:
    def test_methods_endpoint_returns_json(self, client):
        aid = _create_analysis(client)
        resp = client.get(f"/api/v1/analyses/{aid}/methods")
        assert resp.status_code == 200
        data = resp.json()
        assert "analysis_id" in data
        assert "methods" in data

    def test_methods_endpoint_analysis_id_matches(self, client):
        aid = _create_analysis(client)
        resp = client.get(f"/api/v1/analyses/{aid}/methods")
        assert resp.json()["analysis_id"] == aid

    def test_methods_endpoint_non_empty_paragraph(self, client):
        """The methods paragraph must contain meaningful content."""
        aid = _create_analysis(client)
        resp = client.get(f"/api/v1/analyses/{aid}/methods")
        para = resp.json()["methods"]
        assert len(para) > 50  # not trivially empty
        assert "." in para    # at least one sentence

    def test_methods_endpoint_contains_engine(self, client):
        aid = _create_analysis(client)
        resp = client.get(f"/api/v1/analyses/{aid}/methods")
        para = resp.json()["methods"]
        assert "XCMS3" in para

    def test_methods_endpoint_404_for_missing(self, client):
        resp = client.get("/api/v1/analyses/nonexistent/methods")
        assert resp.status_code == 404
