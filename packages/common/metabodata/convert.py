"""Format converters for MetaboData objects.

Supports:
- Feature CSV (human-readable tabular format)
- DataFrame (in-memory pandas interchange)
- mzTab-M (PSI metabolomics standard, https://www.psidev.info/mztab)
"""

from __future__ import annotations

import re
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd

from metabodata.core import MetaboData

# ──────────────────────────────────────────────────────────────────────────────
# Constants
# ──────────────────────────────────────────────────────────────────────────────

# Columns in var that are *metadata*, not intensities
_VAR_META_COLS = frozenset(
    {
        "feature_id",
        "mz",
        "rt",
        "compound_name",
        "hmdb_id",
        "kegg_id",
        "adduct",
        "msi_level",
        "is_isf",
        "isf_parent_mz",
    }
)

# mzTab-M section prefixes
_MTD = "MTD"
_SML = "SML"
_SMF = "SMF"
_SME = "SME"
_COM = "COM"

# ──────────────────────────────────────────────────────────────────────────────
# Feature CSV
# ──────────────────────────────────────────────────────────────────────────────


def to_feature_csv(md: MetaboData, path: str | Path) -> None:
    """Export MetaboData as a feature-table CSV.

    Rows = features.  Columns = feature metadata (mz, rt, compound_name, …)
    followed by one intensity column per sample (named by sample_id).

    Parameters
    ----------
    md:
        Source MetaboData object.
    path:
        Destination file path.  A ``.csv`` suffix is appended when absent.
    """
    path = Path(path)
    if path.suffix.lower() != ".csv":
        path = path.with_suffix(".csv")

    df = to_dataframe(md)
    df.to_csv(path, index=False)


def from_feature_csv(
    path: str | Path,
    sample_meta: dict[str, dict[str, Any]] | None = None,
) -> MetaboData:
    """Import MetaboData from a feature-table CSV.

    The function auto-detects ``mz`` and ``rt`` columns (case-insensitive).
    All remaining numeric columns that are not recognised feature-metadata
    columns are treated as sample intensity columns.

    Parameters
    ----------
    path:
        Path to a CSV file previously written by :func:`to_feature_csv` (or
        any compatible feature table).
    sample_meta:
        Optional per-sample metadata.  Keys are sample IDs (column names);
        values are dicts with any subset of ``{group, batch, sample_type}``.
        Missing values are filled with ``"unknown"`` / ``"batch1"`` /
        ``"sample"`` respectively.

    Returns
    -------
    MetaboData
    """
    df = pd.read_csv(Path(path))

    # Normalise column names for detection (preserve originals)
    col_lower = {c: c.lower() for c in df.columns}

    # Identify mz / rt columns
    mz_col = _find_col(df.columns, ("mz", "m/z", "mz_da", "mz_mda"))
    rt_col = _find_col(df.columns, ("rt", "retention_time", "rt_min", "rt_s"))

    if mz_col is None:
        raise ValueError("Cannot detect mz column in CSV.  Expected one of: mz, m/z, mz_da")
    if rt_col is None:
        raise ValueError("Cannot detect rt column in CSV.  Expected one of: rt, retention_time, rt_min")

    # Known metadata columns (lower-cased match)
    known_meta_lower = {c.lower() for c in _VAR_META_COLS}

    # Sample intensity columns: numeric and not recognised as metadata
    sample_cols: list[str] = []
    for col in df.columns:
        if col_lower[col] in known_meta_lower:
            continue
        if pd.api.types.is_numeric_dtype(df[col]):
            sample_cols.append(col)

    if not sample_cols:
        raise ValueError("No sample intensity columns detected in CSV.")

    return from_dataframe(
        df,
        sample_cols=sample_cols,
        mz_col=mz_col,
        rt_col=rt_col,
        sample_meta=sample_meta,
    )


# ──────────────────────────────────────────────────────────────────────────────
# DataFrame interchange
# ──────────────────────────────────────────────────────────────────────────────


def to_dataframe(md: MetaboData) -> pd.DataFrame:
    """Convert MetaboData to a flat DataFrame.

    Rows = features.  Columns = all var columns (feature_id, mz, rt, …)
    followed by sample intensity columns named by ``obs.sample_id``.

    Returns
    -------
    pd.DataFrame
        Shape (n_features, n_var_cols + n_samples).
    """
    sample_ids = md.obs["sample_id"].tolist()

    # Detect column name conflicts between var columns and sample IDs
    var_cols = list(md.var.columns)
    conflict = set(var_cols) & set(sample_ids)
    if conflict:
        raise ValueError(
            f"Column name conflict: var columns and sample_ids share names: {conflict}. "
            "Rename either the var columns or the sample IDs before exporting."
        )

    # Build intensity sub-frame (features × samples)
    intensity_df = pd.DataFrame(
        md.X.T,  # shape: (n_features, n_samples)
        columns=sample_ids,
    )

    result = pd.concat(
        [md.var.reset_index(drop=True), intensity_df.reset_index(drop=True)],
        axis=1,
    )
    return result


def from_dataframe(
    df: pd.DataFrame,
    sample_cols: list[str],
    mz_col: str = "mz",
    rt_col: str = "rt",
    sample_meta: dict[str, dict[str, Any]] | None = None,
) -> MetaboData:
    """Build a MetaboData from a flat DataFrame.

    Parameters
    ----------
    df:
        Source DataFrame.  Must contain ``mz_col``, ``rt_col``, and all
        columns listed in ``sample_cols``.
    sample_cols:
        Column names that represent sample intensities.  The order determines
        the sample order in ``X``.
    mz_col:
        Name of the m/z column.
    rt_col:
        Name of the retention-time column.
    sample_meta:
        Optional per-sample metadata.  See :func:`from_feature_csv`.

    Returns
    -------
    MetaboData
    """
    if mz_col not in df.columns:
        raise ValueError(f"mz column '{mz_col}' not found in DataFrame.")
    if rt_col not in df.columns:
        raise ValueError(f"rt column '{rt_col}' not found in DataFrame.")
    missing = [c for c in sample_cols if c not in df.columns]
    if missing:
        raise ValueError(f"Sample columns not found in DataFrame: {missing}")

    n_features = len(df)

    # Build var DataFrame
    var_col_names = [mz_col, rt_col]
    # Carry over optional metadata columns if present
    optional_meta = [
        "feature_id", "compound_name", "hmdb_id", "kegg_id",
        "adduct", "msi_level", "is_isf", "isf_parent_mz",
    ]
    present_optional = [c for c in optional_meta if c in df.columns and c not in (mz_col, rt_col)]
    var_col_names = present_optional + [mz_col, rt_col]

    # Deduplicate while preserving order
    seen: set[str] = set()
    var_col_names_dedup: list[str] = []
    for c in var_col_names:
        if c not in seen:
            var_col_names_dedup.append(c)
            seen.add(c)

    var = df[var_col_names_dedup].copy().reset_index(drop=True)

    # Ensure feature_id exists
    if "feature_id" not in var.columns:
        var.insert(0, "feature_id", [f"f{i+1}" for i in range(n_features)])

    # Ensure mz/rt columns exist with correct names
    if mz_col != "mz":
        var = var.rename(columns={mz_col: "mz"})
    if rt_col != "rt":
        var = var.rename(columns={rt_col: "rt"})

    # Cast mz/rt to float
    var["mz"] = var["mz"].astype(float)
    var["rt"] = var["rt"].astype(float)

    # X matrix: samples × features
    # df[sample_cols] has shape (n_features, n_samples) — transpose to (n_samples, n_features)
    X = df[sample_cols].to_numpy(dtype=np.float64).T

    # Build obs DataFrame
    sample_meta = sample_meta or {}
    obs_rows = []
    for sid in sample_cols:
        meta = sample_meta.get(sid, {})
        obs_rows.append(
            {
                "sample_id": sid,
                "group": meta.get("group", "unknown"),
                "batch": meta.get("batch", "batch1"),
                "sample_type": meta.get("sample_type", "sample"),
            }
        )
    obs = pd.DataFrame(obs_rows)

    return MetaboData(X=X, obs=obs, var=var)


# ──────────────────────────────────────────────────────────────────────────────
# mzTab-M
# ──────────────────────────────────────────────────────────────────────────────


def to_mztabm(md: MetaboData, path: str | Path) -> None:
    """Export MetaboData to mzTab-M format (PSI standard).

    Produces a plain-text tab-separated file with four sections:
    - ``MTD`` — metadata block
    - ``SML`` — small molecule summary (one row per feature)
    - ``SMF`` — small molecule feature (one row per feature, with intensities)
    - ``SME`` — small molecule evidence (one row per feature with identifications)

    Only features with a ``compound_name`` in ``var`` get populated SML/SME
    identification fields; unidentified features use ``null`` placeholders per
    the mzTab-M specification.

    Parameters
    ----------
    md:
        Source MetaboData object.
    path:
        Destination ``.mzTab`` file path.
    """
    path = Path(path)
    lines: list[str] = []

    def tab(*fields: Any) -> str:
        return "\t".join(str(f) if f is not None else "null" for f in fields)

    # ── COM header ────────────────────────────────────────────────────────────
    lines.append(tab(_COM, "This is an mzTab-M v2.0 compliant file."))
    lines.append(tab(_COM, f"Created by MetaboFlow on {datetime.now(UTC).isoformat()}"))
    lines.append("")

    # ── MTD block ─────────────────────────────────────────────────────────────
    n_assays = md.n_obs
    sample_ids = md.obs["sample_id"].tolist()

    lines.append(tab(_MTD, "mzTab-version", "2.0.0-M"))
    lines.append(tab(_MTD, "mzTab-mode", "Complete"))
    lines.append(tab(_MTD, "mzTab-type", "Quantification"))
    lines.append(tab(_MTD, "title", md.uns.get("title", "MetaboFlow export")))
    lines.append(tab(_MTD, "description", md.uns.get("description", "Exported from MetaboData")))

    # Quantification unit
    lines.append(tab(_MTD, "quantification_method", "[MS, MS:1001834, LC-MS label-free quantitation analysis, ]"))

    # ms_run entries
    for i, sid in enumerate(sample_ids, start=1):
        lines.append(tab(_MTD, f"ms_run[{i}]-location", f"file:///{sid}.mzML"))

    # assay entries
    for i, sid in enumerate(sample_ids, start=1):
        lines.append(tab(_MTD, f"assay[{i}]-name", sid))
        lines.append(tab(_MTD, f"assay[{i}]-ms_run_ref", f"ms_run[{i}]"))

    # sample entries
    for i, sid in enumerate(sample_ids, start=1):
        group_val = md.obs.iloc[i - 1]["group"]
        lines.append(tab(_MTD, f"sample[{i}]-name", sid))
        lines.append(tab(_MTD, f"sample[{i}]-description", f"group={group_val}"))

    # study_variable entries — one per unique group
    groups = md.obs["group"].unique().tolist()
    for gidx, grp in enumerate(groups, start=1):
        member_indices = [
            str(i + 1)
            for i, row in md.obs.iterrows()
            if row["group"] == grp
        ]
        lines.append(tab(_MTD, f"study_variable[{gidx}]-name", grp))
        lines.append(
            tab(
                _MTD,
                f"study_variable[{gidx}]-assay_refs",
                ",".join(f"assay[{idx}]" for idx in member_indices),
            )
        )

    # small_molecule quantification unit
    lines.append(
        tab(
            _MTD,
            "small_molecule-quantification_unit",
            "[MS, MS:1001844, intensity, ]",
        )
    )
    lines.append(
        tab(
            _MTD,
            "small_molecule_feature-quantification_unit",
            "[MS, MS:1001844, intensity, ]",
        )
    )
    lines.append("")

    # ── SML block ─────────────────────────────────────────────────────────────
    # Columns: SML_ID, SMF_ID_REFS, database_identifier, chemical_formula,
    #          smiles, inchi, chemical_name, uri, theoretical_neutral_mass,
    #          adduct_ions, reliability, best_id_confidence_measure,
    #          best_id_confidence_value,
    #          abundance_assay[1..n]

    sml_header_fixed = [
        "SML_ID", "SMF_ID_REFS", "database_identifier", "chemical_formula",
        "smiles", "inchi", "chemical_name", "uri",
        "theoretical_neutral_mass", "adduct_ions", "reliability",
        "best_id_confidence_measure", "best_id_confidence_value",
    ]
    assay_abundance_cols = [f"abundance_assay[{i}]" for i in range(1, n_assays + 1)]
    lines.append(tab(_SML, *sml_header_fixed, *assay_abundance_cols))

    var = md.var.reset_index(drop=True)
    for feat_idx in range(md.n_vars):
        row = var.iloc[feat_idx]
        sml_id = feat_idx + 1
        smf_id_ref = feat_idx + 1

        chem_name = _get_opt(row, "compound_name")
        hmdb_id = _get_opt(row, "hmdb_id")
        kegg_id = _get_opt(row, "kegg_id")

        # database_identifier: pipe-separated if multiple
        db_ids: list[str] = []
        if hmdb_id is not None:
            db_ids.append(f"HMDB:{hmdb_id}")
        if kegg_id is not None:
            db_ids.append(f"KEGG:{kegg_id}")
        db_identifier = "|".join(db_ids) if db_ids else None

        adduct = _get_opt(row, "adduct")
        msi_level = _get_opt(row, "msi_level")
        reliability = str(int(msi_level)) if msi_level is not None else None

        abundances = [_fmt_intensity(md.X[s, feat_idx]) for s in range(n_assays)]

        lines.append(
            tab(
                _SML,
                sml_id,
                smf_id_ref,
                db_identifier,
                None,  # chemical_formula (not in spec)
                None,  # smiles
                None,  # inchi
                chem_name,
                None,  # uri
                row["mz"],  # theoretical_neutral_mass proxy
                adduct,
                reliability,
                None,  # best_id_confidence_measure
                None,  # best_id_confidence_value
                *abundances,
            )
        )
    lines.append("")

    # ── SMF block ─────────────────────────────────────────────────────────────
    # Columns: SMF_ID, SME_ID_REFS, SME_ID_REFS_ambiguity_code,
    #          adduct_ion, isotopomer, exp_mass_to_charge, charge,
    #          retention_time_in_seconds, rt_window, column_name,
    #          abundance_assay[1..n]

    smf_header_fixed = [
        "SMF_ID", "SME_ID_REFS", "SME_ID_REFS_ambiguity_code",
        "adduct_ion", "isotopomer", "exp_mass_to_charge", "charge",
        "retention_time_in_seconds", "rt_window", "column_name",
    ]
    lines.append(tab(_SMF, *smf_header_fixed, *assay_abundance_cols))

    for feat_idx in range(md.n_vars):
        row = var.iloc[feat_idx]
        smf_id = feat_idx + 1
        sme_id_ref = feat_idx + 1
        adduct = _get_opt(row, "adduct")
        abundances = [_fmt_intensity(md.X[s, feat_idx]) for s in range(n_assays)]

        lines.append(
            tab(
                _SMF,
                smf_id,
                sme_id_ref,
                None,  # ambiguity_code
                adduct,
                None,  # isotopomer
                row["mz"],
                None,  # charge
                row["rt"],
                None,  # rt_window
                None,  # column_name
                *abundances,
            )
        )
    lines.append("")

    # ── SME block ─────────────────────────────────────────────────────────────
    # Columns: SME_ID, evidence_input_id, database_identifier, chemical_formula,
    #          smiles, inchi, chemical_name, uri, derivatized_form,
    #          adduct_ion, exp_mass_to_charge, charge, theoretical_mass_to_charge,
    #          spectra_ref, identification_method, ms_level, rank

    sme_header = [
        "SME_ID", "evidence_input_id", "database_identifier", "chemical_formula",
        "smiles", "inchi", "chemical_name", "uri", "derivatized_form",
        "adduct_ion", "exp_mass_to_charge", "charge", "theoretical_mass_to_charge",
        "spectra_ref", "identification_method", "ms_level", "rank",
    ]
    lines.append(tab(_SME, *sme_header))

    for feat_idx in range(md.n_vars):
        row = var.iloc[feat_idx]
        sme_id = feat_idx + 1
        chem_name = _get_opt(row, "compound_name")
        hmdb_id = _get_opt(row, "hmdb_id")
        kegg_id = _get_opt(row, "kegg_id")

        db_ids = []
        if hmdb_id is not None:
            db_ids.append(f"HMDB:{hmdb_id}")
        if kegg_id is not None:
            db_ids.append(f"KEGG:{kegg_id}")
        db_identifier = "|".join(db_ids) if db_ids else None

        adduct = _get_opt(row, "adduct")
        msi_level = _get_opt(row, "msi_level")

        lines.append(
            tab(
                _SME,
                sme_id,
                row["feature_id"],
                db_identifier,
                None,  # chemical_formula
                None,  # smiles
                None,  # inchi
                chem_name,
                None,  # uri
                None,  # derivatized_form
                adduct,
                row["mz"],
                None,  # charge
                row["mz"],  # theoretical_mass_to_charge (proxy)
                None,  # spectra_ref
                None,  # identification_method
                f"[MS, MS:1000511, ms level {msi_level}, ]" if msi_level is not None else None,
                1,    # rank
            )
        )
    lines.append("")

    path.write_text("\n".join(lines), encoding="utf-8")


def from_mztabm(path: str | Path) -> MetaboData:
    """Import MetaboData from an mzTab-M file.

    Parses MTD, SML, SMF, and SME sections.  Sample intensities are taken
    from ``SMF`` ``abundance_assay[*]`` columns; sample names are taken from
    the ``assay[*]-name`` MTD entries.

    Parameters
    ----------
    path:
        Path to an mzTab-M file.

    Returns
    -------
    MetaboData
    """
    path = Path(path)
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()

    # ── Parse MTD ─────────────────────────────────────────────────────────────
    mtd: dict[str, str] = {}
    sml_lines: list[list[str]] = []
    smf_lines: list[list[str]] = []
    sme_lines: list[list[str]] = []

    for line in lines:
        line = line.rstrip("\r")
        if not line or line.startswith(_COM + "\t"):
            continue
        parts = line.split("\t")
        section = parts[0].strip()

        if section == _MTD:
            if len(parts) >= 3:
                mtd[parts[1].strip()] = parts[2].strip()
        elif section == _SML:
            sml_lines.append(parts[1:])
        elif section == _SMF:
            smf_lines.append(parts[1:])
        elif section == _SME:
            sme_lines.append(parts[1:])

    # ── Reconstruct assay order from MTD ──────────────────────────────────────
    assay_names: dict[int, str] = {}
    for key, val in mtd.items():
        m = re.match(r"assay\[(\d+)\]-name", key)
        if m:
            assay_names[int(m.group(1))] = val

    n_assays = len(assay_names)
    if n_assays == 0:
        raise ValueError("No assay entries found in MTD section.")

    sample_ids = [assay_names[i] for i in sorted(assay_names)]

    # ── Parse obs from MTD ────────────────────────────────────────────────────
    assay_to_msrun: dict[int, str] = {}
    for key, val in mtd.items():
        m = re.match(r"assay\[(\d+)\]-ms_run_ref", key)
        if m:
            assay_to_msrun[int(m.group(1))] = val

    # sample descriptions: group info
    sample_groups: dict[str, str] = {}
    for key, val in mtd.items():
        m = re.match(r"sample\[(\d+)\]-description", key)
        if m:
            # val is like "group=control"
            gm = re.search(r"group=(\S+)", val)
            sid_key = f"sample[{m.group(1)}]-name"
            sid = mtd.get(sid_key, f"sample_{m.group(1)}")
            if gm:
                sample_groups[sid] = gm.group(1)

    obs_rows = []
    for _i, sid in enumerate(sample_ids, start=1):
        obs_rows.append(
            {
                "sample_id": sid,
                "group": sample_groups.get(sid, "unknown"),
                "batch": "batch1",
                "sample_type": "sample",
            }
        )
    obs = pd.DataFrame(obs_rows)

    # ── Parse SMF (intensities) ───────────────────────────────────────────────
    if len(smf_lines) < 2:
        raise ValueError("SMF section missing or has no data rows.")

    smf_header = smf_lines[0]
    smf_data = smf_lines[1:]

    # Locate abundance columns
    abundance_pattern = re.compile(r"abundance_assay\[(\d+)\]")
    abundance_col_indices: dict[int, int] = {}  # assay_idx -> col_pos
    for col_pos, col_name in enumerate(smf_header):
        m = abundance_pattern.match(col_name)
        if m:
            abundance_col_indices[int(m.group(1))] = col_pos

    mz_col_idx = _header_index(smf_header, "exp_mass_to_charge")
    rt_col_idx = _header_index(smf_header, "retention_time_in_seconds")
    adduct_col_idx = _header_index(smf_header, "adduct_ion")
    smf_id_col_idx = _header_index(smf_header, "SMF_ID")

    # ── Parse SML (compound info) ─────────────────────────────────────────────
    sml_by_smf_id: dict[int, dict[str, Any]] = {}
    if len(sml_lines) >= 2:
        sml_header = sml_lines[0]
        sml_data = sml_lines[1:]
        sml_smf_ref_idx = _header_index(sml_header, "SMF_ID_REFS")
        sml_chem_name_idx = _header_index(sml_header, "chemical_name")
        sml_db_idx = _header_index(sml_header, "database_identifier")
        sml_adduct_idx = _header_index(sml_header, "adduct_ions")
        sml_reliability_idx = _header_index(sml_header, "reliability")

        for row in sml_data:
            smf_ref_raw = _get_cell(row, sml_smf_ref_idx)
            if smf_ref_raw is None:
                continue
            try:
                smf_ref = int(smf_ref_raw)
            except ValueError:
                continue

            chem_name = _get_cell(row, sml_chem_name_idx)
            db_id_raw = _get_cell(row, sml_db_idx)
            adduct = _get_cell(row, sml_adduct_idx)
            reliability = _get_cell(row, sml_reliability_idx)

            hmdb_id = None
            kegg_id = None
            if db_id_raw:
                for part in db_id_raw.split("|"):
                    part = part.strip()
                    if part.startswith("HMDB:"):
                        hmdb_id = part[5:]
                    elif part.startswith("KEGG:"):
                        kegg_id = part[5:]

            sml_by_smf_id[smf_ref] = {
                "compound_name": chem_name,
                "hmdb_id": hmdb_id,
                "kegg_id": kegg_id,
                "adduct": adduct,
                "msi_level": int(reliability) if reliability and reliability.isdigit() else None,
            }

    # ── Build X and var ───────────────────────────────────────────────────────
    n_features = len(smf_data)
    if n_features == 0:
        raise ValueError("SMF section has no data rows.")

    X = np.full((n_assays, n_features), np.nan, dtype=np.float64)
    var_rows: list[dict[str, Any]] = []

    for feat_idx, row in enumerate(smf_data):
        smf_id_raw = _get_cell(row, smf_id_col_idx)
        smf_id = int(smf_id_raw) if smf_id_raw and smf_id_raw.isdigit() else feat_idx + 1

        mz_raw = _get_cell(row, mz_col_idx)
        rt_raw = _get_cell(row, rt_col_idx)
        adduct_raw = _get_cell(row, adduct_col_idx)

        mz = float(mz_raw) if mz_raw is not None else float("nan")
        rt = float(rt_raw) if rt_raw is not None else float("nan")

        sml_info = sml_by_smf_id.get(smf_id, {})

        var_row: dict[str, Any] = {
            "feature_id": f"f{smf_id}",
            "mz": mz,
            "rt": rt,
        }
        if sml_info.get("compound_name") is not None:
            var_row["compound_name"] = sml_info["compound_name"]
        if sml_info.get("hmdb_id") is not None:
            var_row["hmdb_id"] = sml_info["hmdb_id"]
        if sml_info.get("kegg_id") is not None:
            var_row["kegg_id"] = sml_info["kegg_id"]
        adduct_final = sml_info.get("adduct") or adduct_raw
        if adduct_final is not None:
            var_row["adduct"] = adduct_final
        if sml_info.get("msi_level") is not None:
            var_row["msi_level"] = sml_info["msi_level"]

        var_rows.append(var_row)

        # Fill intensities
        for assay_idx in sorted(abundance_col_indices):
            col_pos = abundance_col_indices[assay_idx]
            val_raw = _get_cell(row, col_pos)
            sample_row = assay_idx - 1  # 0-based
            if sample_row < n_assays:
                X[sample_row, feat_idx] = float(val_raw) if val_raw is not None else float("nan")

    var = pd.DataFrame(var_rows)
    # Ensure float types for mz/rt
    var["mz"] = var["mz"].astype(float)
    var["rt"] = var["rt"].astype(float)

    return MetaboData(X=X, obs=obs, var=var)


# ──────────────────────────────────────────────────────────────────────────────
# Private helpers
# ──────────────────────────────────────────────────────────────────────────────


def _find_col(columns: list[str] | pd.Index, candidates: tuple[str, ...]) -> str | None:
    """Return the first column whose lower-cased name matches a candidate."""
    lower_map = {c.lower(): c for c in columns}
    for cand in candidates:
        if cand.lower() in lower_map:
            return lower_map[cand.lower()]
    return None


def _get_opt(row: pd.Series, col: str) -> Any | None:
    """Return row[col] if col exists and value is not NaN/None, else None."""
    if col not in row.index:
        return None
    val = row[col]
    if val is None:
        return None
    try:
        if pd.isna(val):
            return None
    except (TypeError, ValueError):
        pass
    return val


def _fmt_intensity(val: float) -> str | None:
    """Format an intensity value; return None for NaN."""
    if np.isnan(val):
        return None
    return str(val)


def _header_index(header: list[str], name: str) -> int | None:
    """Return index of ``name`` in ``header``, or None if absent."""
    try:
        return header.index(name)
    except ValueError:
        return None


def _get_cell(row: list[str], idx: int | None) -> str | None:
    """Safely retrieve a cell; returns None for out-of-range or 'null'."""
    if idx is None or idx >= len(row):
        return None
    val = row[idx].strip()
    return None if val in ("null", "", "NULL") else val
