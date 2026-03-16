"""HDF5 serialization for MetaboData objects.

File format: .metabodata (HDF5)

Structure:
    /X                  float32 (n_samples, n_features)
    /obs/               group — sample metadata
        index           string array
        {column}        typed arrays
    /var/               group — feature metadata
        index           string array
        {column}        typed arrays
    /layers/            group — alternative intensity matrices
        {name}          float32 (n_samples, n_features)
    /obsm/              group — sample embeddings
        {name}          float32
    /varm/              group — feature embeddings
        {name}          float32
    /uns                JSON string — unstructured metadata
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import h5py
import numpy as np
import pandas as pd

from metabodata.core import MetaboData


def save_metabodata(md: MetaboData, path: str | Path) -> None:
    """Save MetaboData to HDF5 file."""
    path = Path(path)
    if path.suffix not in (".metabodata", ".h5"):
        path = path.with_suffix(".metabodata")

    with h5py.File(path, "w") as f:
        # X matrix
        f.create_dataset("X", data=md.X.astype(np.float32), compression="gzip")

        # obs (sample metadata)
        obs_grp = f.create_group("obs")
        _write_dataframe(obs_grp, md.obs)

        # var (feature metadata)
        var_grp = f.create_group("var")
        _write_dataframe(var_grp, md.var)

        # layers
        if md.layers:
            layers_grp = f.create_group("layers")
            for name, data in md.layers.items():
                layers_grp.create_dataset(
                    name, data=data.astype(np.float32), compression="gzip"
                )

        # obsm
        if md.obsm:
            obsm_grp = f.create_group("obsm")
            for name, data in md.obsm.items():
                obsm_grp.create_dataset(
                    name, data=data.astype(np.float32), compression="gzip"
                )

        # varm
        if md.varm:
            varm_grp = f.create_group("varm")
            for name, data in md.varm.items():
                varm_grp.create_dataset(
                    name, data=data.astype(np.float32), compression="gzip"
                )

        # uns (as JSON string)
        uns_json = json.dumps(md.uns, default=str, ensure_ascii=False)
        f.create_dataset("uns", data=uns_json)


def load_metabodata(path: str | Path) -> MetaboData:
    """Load MetaboData from HDF5 file."""
    path = Path(path)

    with h5py.File(path, "r") as f:
        # X matrix
        X = np.array(f["X"])

        # obs
        obs = _read_dataframe(f["obs"])

        # var
        var = _read_dataframe(f["var"])

        # layers
        layers: dict[str, np.ndarray] = {}
        if "layers" in f:
            for name in f["layers"]:
                layers[name] = np.array(f["layers"][name])

        # obsm
        obsm: dict[str, np.ndarray] = {}
        if "obsm" in f:
            for name in f["obsm"]:
                obsm[name] = np.array(f["obsm"][name])

        # varm
        varm: dict[str, np.ndarray] = {}
        if "varm" in f:
            for name in f["varm"]:
                varm[name] = np.array(f["varm"][name])

        # uns
        uns: dict[str, Any] = {}
        if "uns" in f:
            uns_raw = f["uns"][()]
            if isinstance(uns_raw, bytes):
                uns_raw = uns_raw.decode("utf-8")
            uns = json.loads(uns_raw)

    return MetaboData(
        X=X, obs=obs, var=var, obsm=obsm, varm=varm, layers=layers, uns=uns
    )


def _write_dataframe(group: h5py.Group, df: pd.DataFrame) -> None:
    """Write a pandas DataFrame to an HDF5 group."""
    # Store index
    index_data = df.index.astype(str).to_numpy()
    group.create_dataset("_index", data=index_data.astype(bytes))

    # Store column names
    col_names = list(df.columns)
    group.attrs["column_names"] = json.dumps(col_names)

    for col in df.columns:
        series = df[col]
        if pd.api.types.is_float_dtype(series):
            group.create_dataset(col, data=series.to_numpy(dtype=np.float64))
        elif pd.api.types.is_integer_dtype(series):
            group.create_dataset(col, data=series.to_numpy(dtype=np.int64))
        elif pd.api.types.is_bool_dtype(series):
            group.create_dataset(col, data=series.to_numpy(dtype=bool))
        else:
            # String/object columns
            str_data = series.fillna("").astype(str).to_numpy()
            group.create_dataset(col, data=str_data.astype(bytes))


def _read_dataframe(group: h5py.Group) -> pd.DataFrame:
    """Read a pandas DataFrame from an HDF5 group."""
    # Read index
    index = np.array(group["_index"]).astype(str)

    # Read column names (ordered)
    col_names: list[str] = json.loads(group.attrs["column_names"])

    data: dict[str, Any] = {}
    for col in col_names:
        raw = np.array(group[col])
        if raw.dtype.kind == "S" or raw.dtype.kind == "O":
            data[col] = raw.astype(str)
        else:
            data[col] = raw

    df = pd.DataFrame(data, index=index)
    return df
