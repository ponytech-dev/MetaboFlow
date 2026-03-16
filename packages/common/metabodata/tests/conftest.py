"""Shared test fixtures for MetaboData tests."""

import numpy as np
import pandas as pd
import pytest

from metabodata.core import MetaboData


@pytest.fixture
def sample_obs() -> pd.DataFrame:
    """Sample metadata with 4 samples."""
    return pd.DataFrame(
        {
            "sample_id": ["s1", "s2", "s3", "s4"],
            "group": ["control", "control", "treatment", "treatment"],
            "batch": ["batch1", "batch1", "batch1", "batch1"],
            "sample_type": ["sample", "sample", "sample", "qc"],
        }
    )


@pytest.fixture
def sample_var() -> pd.DataFrame:
    """Feature metadata with 3 features."""
    return pd.DataFrame(
        {
            "feature_id": ["f1", "f2", "f3"],
            "mz": [100.0505, 200.1182, 300.2001],
            "rt": [60.5, 120.3, 180.7],
        }
    )


@pytest.fixture
def sample_X() -> np.ndarray:
    """4 samples x 3 features intensity matrix."""
    rng = np.random.default_rng(42)
    return rng.random((4, 3)).astype(np.float32) * 1e6


@pytest.fixture
def sample_metabodata(
    sample_X: np.ndarray, sample_obs: pd.DataFrame, sample_var: pd.DataFrame
) -> MetaboData:
    """A valid MetaboData instance."""
    return MetaboData(X=sample_X, obs=sample_obs, var=sample_var)
