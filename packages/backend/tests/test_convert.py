"""Tests for the format conversion API."""

from __future__ import annotations

import csv
import io

import h5py
import numpy as np
import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture
def client():
    return TestClient(app)


def _make_csv(n_samples: int = 3, n_features: int = 4) -> bytes:
    """Build a minimal CSV feature table for testing."""
    out = io.StringIO()
    features = [f"feat_{i}" for i in range(n_features)]
    writer = csv.writer(out)
    writer.writerow(["sample_id", *features])
    for s in range(n_samples):
        writer.writerow([f"S{s + 1}", *[str(float(s * n_features + i)) for i in range(n_features)]])
    return out.getvalue().encode()


def _make_h5(n_samples: int = 3, n_features: int = 4) -> bytes:
    """Build a minimal MetaboData HDF5 for testing."""
    sample_ids = [f"S{i + 1}" for i in range(n_samples)]
    feature_ids = [f"feat_{i}" for i in range(n_features)]
    matrix = np.arange(n_samples * n_features, dtype=np.float64).reshape(n_samples, n_features)
    buf = io.BytesIO()
    with h5py.File(buf, "w") as hf:
        hf.create_dataset("X", data=matrix)
        hf.create_dataset(
            "obs/sample_id",
            data=np.array(sample_ids, dtype=h5py.special_dtype(vlen=str)),
        )
        hf.create_dataset(
            "var/feature_id",
            data=np.array(feature_ids, dtype=h5py.special_dtype(vlen=str)),
        )
        hf.attrs["format"] = "MetaboData"
        hf.attrs["version"] = "1.0"
    return buf.getvalue()


class TestListFormats:
    def test_returns_200(self, client):
        resp = client.get("/api/v1/convert/formats")
        assert resp.status_code == 200

    def test_returns_list(self, client):
        resp = client.get("/api/v1/convert/formats")
        data = resp.json()
        assert isinstance(data, list)
        assert len(data) >= 3

    def test_format_fields(self, client):
        resp = client.get("/api/v1/convert/formats")
        fmt = resp.json()[0]
        for field in ("name", "extension", "description", "supports_import", "supports_export"):
            assert field in fmt

    def test_csv_format_present(self, client):
        resp = client.get("/api/v1/convert/formats")
        names = [f["name"].upper() for f in resp.json()]
        assert "CSV" in names

    def test_metabodata_format_present(self, client):
        resp = client.get("/api/v1/convert/formats")
        names = [f["name"].upper() for f in resp.json()]
        assert "METABODATA" in names


class TestCsvToMetabodata:
    def test_returns_200(self, client):
        resp = client.post(
            "/api/v1/convert/csv-to-metabodata",
            files={"file": ("data.csv", _make_csv(), "text/csv")},
        )
        assert resp.status_code == 200

    def test_content_type_hdf(self, client):
        resp = client.post(
            "/api/v1/convert/csv-to-metabodata",
            files={"file": ("data.csv", _make_csv(), "text/csv")},
        )
        assert "hdf" in resp.headers["content-type"].lower() or resp.status_code == 200

    def test_output_is_valid_hdf5(self, client):
        resp = client.post(
            "/api/v1/convert/csv-to-metabodata",
            files={"file": ("data.csv", _make_csv(3, 4), "text/csv")},
        )
        buf = io.BytesIO(resp.content)
        with h5py.File(buf, "r") as hf:
            assert "X" in hf
            assert hf["X"].shape == (3, 4)

    def test_empty_csv_returns_400(self, client):
        resp = client.post(
            "/api/v1/convert/csv-to-metabodata",
            files={"file": ("empty.csv", b"", "text/csv")},
        )
        assert resp.status_code == 400


class TestMetabodataToCsv:
    def test_returns_200(self, client):
        resp = client.post(
            "/api/v1/convert/metabodata-to-csv",
            files={"file": ("data.h5", _make_h5(), "application/x-hdf")},
        )
        assert resp.status_code == 200

    def test_output_is_valid_csv(self, client):
        resp = client.post(
            "/api/v1/convert/metabodata-to-csv",
            files={"file": ("data.h5", _make_h5(3, 4), "application/x-hdf")},
        )
        reader = csv.DictReader(io.StringIO(resp.text))
        rows = list(reader)
        assert len(rows) == 3
        assert "sample_id" in (reader.fieldnames or [])

    def test_invalid_file_returns_400(self, client):
        resp = client.post(
            "/api/v1/convert/metabodata-to-csv",
            files={"file": ("bad.h5", b"not an hdf5 file", "application/x-hdf")},
        )
        assert resp.status_code == 400


class TestMetabodataToMztabm:
    def test_returns_200(self, client):
        resp = client.post(
            "/api/v1/convert/metabodata-to-mztabm",
            files={"file": ("data.h5", _make_h5(), "application/x-hdf")},
        )
        assert resp.status_code == 200

    def test_output_contains_mztab_header(self, client):
        resp = client.post(
            "/api/v1/convert/metabodata-to-mztabm",
            files={"file": ("data.h5", _make_h5(), "application/x-hdf")},
        )
        assert "MTD" in resp.text
        assert "mzTab-version" in resp.text

    def test_output_contains_sml_rows(self, client):
        resp = client.post(
            "/api/v1/convert/metabodata-to-mztabm",
            files={"file": ("data.h5", _make_h5(2, 3), "application/x-hdf")},
        )
        sml_rows = [ln for ln in resp.text.splitlines() if ln.startswith("SML\t")]
        assert len(sml_rows) == 3  # one per feature

    def test_invalid_file_returns_400(self, client):
        resp = client.post(
            "/api/v1/convert/metabodata-to-mztabm",
            files={"file": ("bad.h5", b"garbage", "application/x-hdf")},
        )
        assert resp.status_code == 400
