"""Tests for MetaboData HDF5 serialization."""

import json
from pathlib import Path

import h5py
import numpy as np
import pandas as pd

from metabodata.core import MetaboData
from metabodata.io import load_metabodata, save_metabodata


class TestRoundTrip:
    """Test save/load round-trip preserves all data."""

    def test_basic_round_trip(
        self, sample_metabodata: MetaboData, tmp_path: Path
    ) -> None:
        path = tmp_path / "test.metabodata"
        save_metabodata(sample_metabodata, path)
        loaded = load_metabodata(path)

        np.testing.assert_array_almost_equal(loaded.X, sample_metabodata.X, decimal=5)
        assert list(loaded.obs.columns) == list(sample_metabodata.obs.columns)
        assert list(loaded.var.columns) == list(sample_metabodata.var.columns)
        assert loaded.n_obs == sample_metabodata.n_obs
        assert loaded.n_vars == sample_metabodata.n_vars

    def test_round_trip_with_layers(
        self, sample_metabodata: MetaboData, tmp_path: Path
    ) -> None:
        raw = sample_metabodata.X * 2
        log2 = np.log2(sample_metabodata.X + 1)
        sample_metabodata.add_layer("raw", raw)
        sample_metabodata.add_layer("log2", log2)

        path = tmp_path / "test.metabodata"
        save_metabodata(sample_metabodata, path)
        loaded = load_metabodata(path)

        assert set(loaded.layers.keys()) == {"raw", "log2"}
        np.testing.assert_array_almost_equal(loaded.layers["raw"], raw, decimal=5)

    def test_round_trip_with_obsm_varm(
        self, sample_metabodata: MetaboData, tmp_path: Path
    ) -> None:
        pca_scores = np.random.default_rng(42).random((4, 2)).astype(np.float32)
        pca_loadings = np.random.default_rng(42).random((3, 2)).astype(np.float32)
        sample_metabodata.obsm["pca"] = pca_scores
        sample_metabodata.varm["pca_loadings"] = pca_loadings

        path = tmp_path / "test.metabodata"
        save_metabodata(sample_metabodata, path)
        loaded = load_metabodata(path)

        assert "pca" in loaded.obsm
        assert "pca_loadings" in loaded.varm
        np.testing.assert_array_almost_equal(loaded.obsm["pca"], pca_scores, decimal=5)

    def test_round_trip_with_uns(
        self, sample_metabodata: MetaboData, tmp_path: Path
    ) -> None:
        sample_metabodata.uns["custom_key"] = {"nested": [1, 2, 3]}
        sample_metabodata.add_provenance_step(
            "peak_detection", "xcms", "4.4.0", {"ppm": 15}
        )

        path = tmp_path / "test.metabodata"
        save_metabodata(sample_metabodata, path)
        loaded = load_metabodata(path)

        assert loaded.uns["custom_key"] == {"nested": [1, 2, 3]}
        assert len(loaded.uns["provenance"]["steps"]) == 1
        assert loaded.uns["provenance"]["steps"][0]["engine"] == "xcms"

    def test_round_trip_obs_values(
        self, sample_metabodata: MetaboData, tmp_path: Path
    ) -> None:
        path = tmp_path / "test.metabodata"
        save_metabodata(sample_metabodata, path)
        loaded = load_metabodata(path)

        assert list(loaded.obs["sample_id"]) == list(
            sample_metabodata.obs["sample_id"]
        )
        assert list(loaded.obs["group"]) == list(sample_metabodata.obs["group"])
        assert list(loaded.obs["sample_type"]) == list(
            sample_metabodata.obs["sample_type"]
        )

    def test_round_trip_var_values(
        self, sample_metabodata: MetaboData, tmp_path: Path
    ) -> None:
        path = tmp_path / "test.metabodata"
        save_metabodata(sample_metabodata, path)
        loaded = load_metabodata(path)

        np.testing.assert_array_almost_equal(
            loaded.var["mz"].to_numpy(),
            sample_metabodata.var["mz"].to_numpy(),
            decimal=4,
        )
        np.testing.assert_array_almost_equal(
            loaded.var["rt"].to_numpy(),
            sample_metabodata.var["rt"].to_numpy(),
            decimal=1,
        )

    def test_round_trip_optional_var_columns(self, tmp_path: Path) -> None:
        """Test var with optional annotation columns."""
        X = np.array([[1.0, 2.0], [3.0, 4.0]], dtype=np.float32)
        obs = pd.DataFrame(
            {
                "sample_id": ["s1", "s2"],
                "group": ["a", "b"],
                "batch": ["b1", "b1"],
                "sample_type": ["sample", "sample"],
            }
        )
        var = pd.DataFrame(
            {
                "feature_id": ["f1", "f2"],
                "mz": [100.05, 200.11],
                "rt": [60.0, 120.0],
                "compound_name": ["Glucose", ""],
                "hmdb_id": ["HMDB0000122", ""],
                "msi_level": [1.0, 4.0],
                "is_isf": [False, False],
            }
        )
        md = MetaboData(X=X, obs=obs, var=var)

        path = tmp_path / "test.metabodata"
        save_metabodata(md, path)
        loaded = load_metabodata(path)

        assert list(loaded.var["compound_name"]) == ["Glucose", ""]
        assert list(loaded.var["hmdb_id"]) == ["HMDB0000122", ""]


class TestFileFormat:
    """Test HDF5 file structure."""

    def test_file_extension(
        self, sample_metabodata: MetaboData, tmp_path: Path
    ) -> None:
        path = tmp_path / "test"
        save_metabodata(sample_metabodata, path)
        assert (tmp_path / "test.metabodata").exists()

    def test_hdf5_structure(
        self, sample_metabodata: MetaboData, tmp_path: Path
    ) -> None:
        """Verify HDF5 internal structure matches spec."""
        sample_metabodata.add_layer("raw", sample_metabodata.X * 2)
        sample_metabodata.uns["key"] = "value"

        path = tmp_path / "test.metabodata"
        save_metabodata(sample_metabodata, path)

        with h5py.File(path, "r") as f:
            assert "X" in f
            assert "obs" in f
            assert "var" in f
            assert "layers" in f
            assert "uns" in f
            assert "raw" in f["layers"]
            assert f["X"].shape == (4, 3)

    def test_uns_is_json_string(
        self, sample_metabodata: MetaboData, tmp_path: Path
    ) -> None:
        sample_metabodata.uns["test"] = {"nested": True}
        path = tmp_path / "test.metabodata"
        save_metabodata(sample_metabodata, path)

        with h5py.File(path, "r") as f:
            raw = f["uns"][()]
            if isinstance(raw, bytes):
                raw = raw.decode("utf-8")
            parsed = json.loads(raw)
            assert parsed["test"]["nested"] is True


class TestEdgeCases:
    """Test edge cases."""

    def test_empty_layers(
        self, sample_metabodata: MetaboData, tmp_path: Path
    ) -> None:
        path = tmp_path / "test.metabodata"
        save_metabodata(sample_metabodata, path)
        loaded = load_metabodata(path)
        assert loaded.layers == {}

    def test_empty_uns(
        self, sample_metabodata: MetaboData, tmp_path: Path
    ) -> None:
        path = tmp_path / "test.metabodata"
        save_metabodata(sample_metabodata, path)
        loaded = load_metabodata(path)
        assert loaded.uns == {}
