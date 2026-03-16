"""Format conversion API routes."""

from __future__ import annotations

import csv
import io

import h5py
import numpy as np
from fastapi import APIRouter, HTTPException, UploadFile
from fastapi.responses import Response

from app.models.convert import FormatInfo

router = APIRouter(prefix="/convert", tags=["convert"])

# ── Supported formats registry ────────────────────────────────────────────────

_FORMATS: list[FormatInfo] = [
    FormatInfo(
        name="CSV",
        extension=".csv",
        description="Comma-separated feature table (samples × features)",
        supports_import=True,
        supports_export=True,
    ),
    FormatInfo(
        name="MetaboData",
        extension=".h5",
        description="MetaboFlow internal HDF5 format (AnnData-compatible)",
        supports_import=True,
        supports_export=True,
    ),
    FormatInfo(
        name="mzTab-M",
        extension=".mztab",
        description="HUPO-PSI mzTab-M metabolomics results format",
        supports_import=False,
        supports_export=True,
    ),
]

_FORMAT_MAP = {f.name.lower(): f for f in _FORMATS}


# ── Endpoints ─────────────────────────────────────────────────────────────────


@router.get("/formats", response_model=list[FormatInfo])
async def list_formats() -> list[FormatInfo]:
    """List all supported formats with their capabilities."""
    return _FORMATS


@router.post("/csv-to-metabodata")
async def csv_to_metabodata(file: UploadFile) -> Response:
    """Convert a CSV feature table to MetaboData HDF5 format.

    Expected CSV structure: first column = sample IDs, remaining columns = features.
    """
    if file.filename and not file.filename.endswith(".csv"):
        raise HTTPException(status_code=400, detail="Uploaded file must be a CSV")

    content = await file.read()
    text = content.decode("utf-8")
    reader = csv.DictReader(io.StringIO(text))
    rows = list(reader)

    if not rows:
        raise HTTPException(status_code=400, detail="CSV file is empty")

    fieldnames = reader.fieldnames or []
    if len(fieldnames) < 2:
        raise HTTPException(status_code=400, detail="CSV must have at least two columns")

    sample_col = fieldnames[0]
    feature_cols = fieldnames[1:]

    sample_ids = [r[sample_col] for r in rows]
    matrix = np.array(
        [[float(r.get(col, 0) or 0) for col in feature_cols] for r in rows],
        dtype=np.float64,
    )

    buf = io.BytesIO()
    with h5py.File(buf, "w") as hf:
        hf.create_dataset("X", data=matrix)
        hf.create_dataset(
            "obs/sample_id",
            data=np.array(sample_ids, dtype=h5py.special_dtype(vlen=str)),
        )
        hf.create_dataset(
            "var/feature_id",
            data=np.array(feature_cols, dtype=h5py.special_dtype(vlen=str)),
        )
        hf.attrs["format"] = "MetaboData"
        hf.attrs["version"] = "1.0"
        hf.attrs["source"] = file.filename or "upload.csv"

    stem = (file.filename or "data").removesuffix(".csv")
    return Response(
        content=buf.getvalue(),
        media_type="application/x-hdf",
        headers={"Content-Disposition": f'attachment; filename="{stem}.h5"'},
    )


@router.post("/metabodata-to-csv")
async def metabodata_to_csv(file: UploadFile) -> Response:
    """Convert a MetaboData HDF5 file back to a CSV feature table."""
    content = await file.read()

    try:
        buf = io.BytesIO(content)
        with h5py.File(buf, "r") as hf:
            matrix = hf["X"][:]
            sample_ids = [s.decode() if isinstance(s, bytes) else s for s in hf["obs/sample_id"][:]]
            feature_ids = [f.decode() if isinstance(f, bytes) else f for f in hf["var/feature_id"][:]]
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Invalid MetaboData HDF5 file: {exc}") from exc

    out = io.StringIO()
    writer = csv.writer(out)
    writer.writerow(["sample_id", *feature_ids])
    for i, sid in enumerate(sample_ids):
        writer.writerow([sid, *matrix[i].tolist()])

    stem = (file.filename or "data").removesuffix(".h5")
    return Response(
        content=out.getvalue(),
        media_type="text/csv",
        headers={"Content-Disposition": f'attachment; filename="{stem}.csv"'},
    )


@router.post("/metabodata-to-mztabm")
async def metabodata_to_mztabm(file: UploadFile) -> Response:
    """Export a MetaboData HDF5 file as mzTab-M (plain-text)."""
    content = await file.read()

    try:
        buf = io.BytesIO(content)
        with h5py.File(buf, "r") as hf:
            matrix = hf["X"][:]
            sample_ids = [s.decode() if isinstance(s, bytes) else s for s in hf["obs/sample_id"][:]]
            feature_ids = [f.decode() if isinstance(f, bytes) else f for f in hf["var/feature_id"][:]]
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Invalid MetaboData HDF5 file: {exc}") from exc

    lines: list[str] = []

    # MTD section
    lines.append("COM\tConverted by MetaboFlow")
    lines.append("MTD\tmzTab-version\t2.0.0-M")
    lines.append("MTD\tmzTab-mode\tSummary")
    lines.append("MTD\tmzTab-type\tQuantification")
    lines.append(f"MTD\ttitle\tMetaboFlow export from {file.filename or 'data.h5'}")

    for i, sid in enumerate(sample_ids):
        lines.append(f"MTD\tms_run[{i + 1}]-location\tfile://{sid}.mzML")
        lines.append(f"MTD\tassay[{i + 1}]-ms_run_ref\tms_run[{i + 1}]")

    # SMH header
    lines.append("")
    sml_header_parts = ["SMH", "SML_ID", "SMF_ID_REFS", "database_identifier",
                        "chemical_formula", "smiles", "inchi", "chemical_name",
                        "uri", "theoretical_neutral_mass", "adduct_ions", "reliability",
                        "best_id_confidence_measure", "best_id_confidence_value"]
    sml_header_parts += [f"abundance_assay[{i + 1}]" for i in range(len(sample_ids))]
    lines.append("\t".join(sml_header_parts))

    # SML rows (one per feature)
    for fi, fid in enumerate(feature_ids):
        row_parts = [
            "SML",
            str(fi + 1),          # SML_ID
            str(fi + 1),          # SMF_ID_REFS
            "null",               # database_identifier
            "null",               # chemical_formula
            "null",               # smiles
            "null",               # inchi
            fid,                  # chemical_name (use feature id)
            "null",               # uri
            "null",               # theoretical_neutral_mass
            "null",               # adduct_ions
            "null",               # reliability
            "null",               # best_id_confidence_measure
            "null",               # best_id_confidence_value
        ]
        row_parts += [str(matrix[si, fi]) for si in range(len(sample_ids))]
        lines.append("\t".join(row_parts))

    stem = (file.filename or "data").removesuffix(".h5")
    return Response(
        content="\n".join(lines),
        media_type="text/plain",
        headers={"Content-Disposition": f'attachment; filename="{stem}.mztab"'},
    )
