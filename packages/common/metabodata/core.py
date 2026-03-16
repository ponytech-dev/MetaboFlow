"""MetaboData: standardized intermediate format for metabolomics data.

Inspired by AnnData (scverse), specialized for metabolomics workflows.
All engine adapters produce and consume MetaboData objects.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from datetime import UTC, datetime
from typing import Any

import numpy as np
import pandas as pd

# Required columns in obs and var DataFrames
OBS_REQUIRED_COLUMNS = frozenset({"sample_id", "group", "batch", "sample_type"})
VAR_REQUIRED_COLUMNS = frozenset({"feature_id", "mz", "rt"})
VALID_SAMPLE_TYPES = frozenset({"sample", "qc", "blank"})


class MetaboDataError(Exception):
    """Base exception for MetaboData validation errors."""


@dataclass
class MetaboData:
    """Metabolomics standard intermediate format.

    Attributes:
        X: Feature intensity matrix, shape (n_samples, n_features).
        obs: Sample metadata. Index = sample_id.
             Required columns: sample_id, group, batch, sample_type.
        var: Feature metadata. Index = feature_id.
             Required columns: feature_id, mz, rt.
             Optional: compound_name, hmdb_id, kegg_id, adduct, msi_level, is_isf, isf_parent_mz.
        obsm: Sample-level embeddings, e.g. {"pca": ndarray(n_samples, n_components)}.
        varm: Feature-level embeddings, e.g. {"pca_loadings": ndarray(n_features, n_components)}.
        layers: Alternative intensity matrices, e.g. {"raw", "normalized", "log2", "imputed"}.
        uns: Unstructured metadata: provenance, processing params, QC metrics, pathway results.
    """

    X: np.ndarray
    obs: pd.DataFrame
    var: pd.DataFrame
    obsm: dict[str, np.ndarray] = field(default_factory=dict)
    varm: dict[str, np.ndarray] = field(default_factory=dict)
    layers: dict[str, np.ndarray] = field(default_factory=dict)
    uns: dict[str, Any] = field(default_factory=dict)

    def __post_init__(self) -> None:
        self._validate()

    def _validate(self) -> None:
        """Validate data consistency."""
        # X shape
        if self.X.ndim != 2:
            raise MetaboDataError(f"X must be 2D, got {self.X.ndim}D")

        n_samples, n_features = self.X.shape

        # obs validation
        if len(self.obs) != n_samples:
            raise MetaboDataError(
                f"obs has {len(self.obs)} rows, but X has {n_samples} samples"
            )
        missing_obs = OBS_REQUIRED_COLUMNS - set(self.obs.columns)
        if missing_obs:
            raise MetaboDataError(f"obs missing required columns: {missing_obs}")

        invalid_types = set(self.obs["sample_type"].unique()) - VALID_SAMPLE_TYPES
        if invalid_types:
            raise MetaboDataError(
                f"obs.sample_type contains invalid values: {invalid_types}. "
                f"Valid: {VALID_SAMPLE_TYPES}"
            )

        if self.obs["sample_id"].duplicated().any():
            raise MetaboDataError("obs.sample_id contains duplicates")

        # var validation
        if len(self.var) != n_features:
            raise MetaboDataError(
                f"var has {len(self.var)} rows, but X has {n_features} features"
            )
        missing_var = VAR_REQUIRED_COLUMNS - set(self.var.columns)
        if missing_var:
            raise MetaboDataError(f"var missing required columns: {missing_var}")

        if self.var["feature_id"].duplicated().any():
            raise MetaboDataError("var.feature_id contains duplicates")

        # layers validation
        for name, layer in self.layers.items():
            if layer.shape != self.X.shape:
                raise MetaboDataError(
                    f"Layer '{name}' shape {layer.shape} != X shape {self.X.shape}"
                )

        # obsm validation
        for name, arr in self.obsm.items():
            if arr.shape[0] != n_samples:
                raise MetaboDataError(
                    f"obsm['{name}'] has {arr.shape[0]} rows, expected {n_samples}"
                )

        # varm validation
        for name, arr in self.varm.items():
            if arr.shape[0] != n_features:
                raise MetaboDataError(
                    f"varm['{name}'] has {arr.shape[0]} rows, expected {n_features}"
                )

    @property
    def n_obs(self) -> int:
        return int(self.X.shape[0])

    @property
    def n_vars(self) -> int:
        return int(self.X.shape[1])

    @property
    def shape(self) -> tuple[int, int]:
        return self.X.shape

    def add_layer(self, name: str, data: np.ndarray) -> None:
        """Add an intensity matrix layer."""
        if data.shape != self.X.shape:
            raise MetaboDataError(
                f"Layer '{name}' shape {data.shape} != X shape {self.X.shape}"
            )
        self.layers[name] = data

    def add_provenance_step(
        self,
        step: str,
        engine: str,
        engine_version: str,
        params: dict[str, Any],
    ) -> None:
        """Record a processing step in the provenance chain."""
        if "provenance" not in self.uns:
            self.uns["provenance"] = {
                "created_at": datetime.now(UTC).isoformat(),
                "steps": [],
            }
        self.uns["provenance"]["steps"].append(
            {
                "step": step,
                "engine": engine,
                "engine_version": engine_version,
                "params": params,
                "timestamp": datetime.now(UTC).isoformat(),
            }
        )

    def copy(self) -> MetaboData:
        """Return a deep copy."""
        return MetaboData(
            X=self.X.copy(),
            obs=self.obs.copy(),
            var=self.var.copy(),
            obsm={k: v.copy() for k, v in self.obsm.items()},
            varm={k: v.copy() for k, v in self.varm.items()},
            layers={k: v.copy() for k, v in self.layers.items()},
            uns=json.loads(json.dumps(self.uns)),
        )

    def __repr__(self) -> str:
        return (
            f"MetaboData(n_obs={self.n_obs}, n_vars={self.n_vars}, "
            f"layers={list(self.layers.keys())}, "
            f"obsm={list(self.obsm.keys())}, "
            f"varm={list(self.varm.keys())})"
        )
