"""Tests for MetaboData core class."""

import numpy as np
import pandas as pd
import pytest

from metabodata.core import MetaboData, MetaboDataError


class TestMetaboDataConstruction:
    """Test MetaboData creation and validation."""

    def test_valid_construction(
        self, sample_X: np.ndarray, sample_obs: pd.DataFrame, sample_var: pd.DataFrame
    ) -> None:
        md = MetaboData(X=sample_X, obs=sample_obs, var=sample_var)
        assert md.n_obs == 4
        assert md.n_vars == 3
        assert md.shape == (4, 3)

    def test_missing_obs_column(
        self, sample_X: np.ndarray, sample_var: pd.DataFrame
    ) -> None:
        obs = pd.DataFrame({"sample_id": ["s1", "s2", "s3", "s4"]})
        with pytest.raises(MetaboDataError, match="obs missing required columns"):
            MetaboData(X=sample_X, obs=obs, var=sample_var)

    def test_missing_var_column(
        self, sample_X: np.ndarray, sample_obs: pd.DataFrame
    ) -> None:
        var = pd.DataFrame({"feature_id": ["f1", "f2", "f3"]})
        with pytest.raises(MetaboDataError, match="var missing required columns"):
            MetaboData(X=sample_X, obs=sample_obs, var=var)

    def test_obs_shape_mismatch(
        self, sample_X: np.ndarray, sample_var: pd.DataFrame
    ) -> None:
        obs = pd.DataFrame(
            {
                "sample_id": ["s1", "s2"],
                "group": ["a", "b"],
                "batch": ["b1", "b1"],
                "sample_type": ["sample", "sample"],
            }
        )
        with pytest.raises(MetaboDataError, match="obs has 2 rows"):
            MetaboData(X=sample_X, obs=obs, var=sample_var)

    def test_var_shape_mismatch(
        self, sample_X: np.ndarray, sample_obs: pd.DataFrame
    ) -> None:
        var = pd.DataFrame(
            {"feature_id": ["f1"], "mz": [100.0], "rt": [60.0]}
        )
        with pytest.raises(MetaboDataError, match="var has 1 rows"):
            MetaboData(X=sample_X, obs=sample_obs, var=var)

    def test_x_not_2d(
        self, sample_obs: pd.DataFrame, sample_var: pd.DataFrame
    ) -> None:
        with pytest.raises(MetaboDataError, match="X must be 2D"):
            MetaboData(X=np.array([1, 2, 3]), obs=sample_obs, var=sample_var)

    def test_invalid_sample_type(
        self, sample_X: np.ndarray, sample_var: pd.DataFrame
    ) -> None:
        obs = pd.DataFrame(
            {
                "sample_id": ["s1", "s2", "s3", "s4"],
                "group": ["a", "a", "b", "b"],
                "batch": ["b1", "b1", "b1", "b1"],
                "sample_type": ["sample", "sample", "INVALID", "qc"],
            }
        )
        with pytest.raises(MetaboDataError, match="invalid values"):
            MetaboData(X=sample_X, obs=obs, var=sample_var)

    def test_duplicate_sample_id(
        self, sample_X: np.ndarray, sample_var: pd.DataFrame
    ) -> None:
        obs = pd.DataFrame(
            {
                "sample_id": ["s1", "s1", "s3", "s4"],
                "group": ["a", "a", "b", "b"],
                "batch": ["b1", "b1", "b1", "b1"],
                "sample_type": ["sample", "sample", "sample", "qc"],
            }
        )
        with pytest.raises(MetaboDataError, match="duplicates"):
            MetaboData(X=sample_X, obs=obs, var=sample_var)

    def test_duplicate_feature_id(
        self, sample_X: np.ndarray, sample_obs: pd.DataFrame
    ) -> None:
        var = pd.DataFrame(
            {"feature_id": ["f1", "f1", "f3"], "mz": [100.0, 200.0, 300.0], "rt": [60.0, 120.0, 180.0]}
        )
        with pytest.raises(MetaboDataError, match="duplicates"):
            MetaboData(X=sample_X, obs=sample_obs, var=var)


class TestMetaboDataLayers:
    """Test layer management."""

    def test_add_layer(self, sample_metabodata: MetaboData) -> None:
        raw = sample_metabodata.X * 2
        sample_metabodata.add_layer("raw", raw)
        assert "raw" in sample_metabodata.layers
        np.testing.assert_array_equal(sample_metabodata.layers["raw"], raw)

    def test_add_layer_shape_mismatch(self, sample_metabodata: MetaboData) -> None:
        with pytest.raises(MetaboDataError, match="shape"):
            sample_metabodata.add_layer("bad", np.zeros((2, 2)))

    def test_layer_validated_at_construction(
        self, sample_X: np.ndarray, sample_obs: pd.DataFrame, sample_var: pd.DataFrame
    ) -> None:
        with pytest.raises(MetaboDataError, match="Layer 'bad'"):
            MetaboData(
                X=sample_X,
                obs=sample_obs,
                var=sample_var,
                layers={"bad": np.zeros((2, 2))},
            )


class TestMetaboDataProvenance:
    """Test provenance tracking."""

    def test_add_provenance_step(self, sample_metabodata: MetaboData) -> None:
        sample_metabodata.add_provenance_step(
            step="peak_detection",
            engine="xcms",
            engine_version="4.4.0",
            params={"ppm": 15, "peakwidth": [5, 30]},
        )
        prov = sample_metabodata.uns["provenance"]
        assert "created_at" in prov
        assert len(prov["steps"]) == 1
        assert prov["steps"][0]["engine"] == "xcms"

    def test_multiple_provenance_steps(self, sample_metabodata: MetaboData) -> None:
        sample_metabodata.add_provenance_step("step1", "eng1", "1.0", {})
        sample_metabodata.add_provenance_step("step2", "eng2", "2.0", {"k": "v"})
        assert len(sample_metabodata.uns["provenance"]["steps"]) == 2


class TestMetaboDataCopy:
    """Test deep copy."""

    def test_copy_is_independent(self, sample_metabodata: MetaboData) -> None:
        md2 = sample_metabodata.copy()
        md2.X[0, 0] = -999.0
        assert sample_metabodata.X[0, 0] != -999.0

    def test_copy_preserves_data(self, sample_metabodata: MetaboData) -> None:
        sample_metabodata.add_layer("raw", sample_metabodata.X * 2)
        sample_metabodata.uns["key"] = "value"
        md2 = sample_metabodata.copy()
        assert "raw" in md2.layers
        assert md2.uns["key"] == "value"
        np.testing.assert_array_equal(md2.X, sample_metabodata.X)


class TestMetaboDataRepr:
    """Test string representation."""

    def test_repr(self, sample_metabodata: MetaboData) -> None:
        r = repr(sample_metabodata)
        assert "n_obs=4" in r
        assert "n_vars=3" in r
