#!/usr/bin/env python3
"""
Build spectral library registry: split, convert, tag, and index all MS2 libraries.

Stages:
  1. Split MassBank MSP by instrument type and polarity
  2. Convert GNPS/MSnLib/ISDB MGF → standardized MSP
  3. Copy/rename NORMAN, MS-DIAL MSP files
  4. Convert ReSpect txt → MSP
  5. Convert HMDB experimental XML → MSP
  6. Build SQLite registry with multi-label tags

Usage:
  python scripts/build_library_registry.py [--library-dir ~/spectral_libraries]
"""

import argparse
import os
import re
import sqlite3
import xml.etree.ElementTree as ET
from pathlib import Path

DEFAULT_LIB_DIR = os.path.expanduser("~/spectral_libraries")


# ============================================================
# Stage 1: Split MassBank MSP by instrument + polarity
# ============================================================

INSTRUMENT_MAP = {
    "qtof": ["QTOF"],
    "orbitrap": ["ITFT", "QFT"],
    "qqq": ["QQQ", "QQ"],
    "ion_trap": [],  # special handling
    "ei": ["EI-B", "EI-TOF", "GC-EI"],
}


def classify_instrument(inst_type: str) -> str:
    inst_upper = inst_type.upper()
    for group, patterns in INSTRUMENT_MAP.items():
        for p in patterns:
            if p in inst_upper:
                # Avoid ion_trap matching ITFT (Orbitrap)
                if group == "ion_trap":
                    continue
                return group
    # Special: ion trap without FT
    if "IT" in inst_upper and "FT" not in inst_upper and "TOF" not in inst_upper:
        return "ion_trap"
    if "TOF" in inst_upper:
        return "tof"
    return "other"


def split_massbank(lib_dir: str):
    """Split MassBank_NIST.msp by instrument type and ion mode."""
    src = os.path.join(lib_dir, "raw/massbank/MassBank_NIST.msp")
    out_dir = os.path.join(lib_dir, "converted")
    os.makedirs(out_dir, exist_ok=True)

    if not os.path.exists(src):
        print(f"  SKIP: {src} not found")
        return {}

    print(f"  Splitting MassBank ({src})...")
    # Collect spectra into buckets
    handles = {}  # (instrument, polarity) -> file handle
    counts = {}

    current_lines = []
    current_inst = "other"
    current_pol = "positive"

    with open(src, encoding="utf-8", errors="replace") as f:
        for line in f:
            stripped = line.strip()

            if stripped.startswith("Instrument_type:"):
                inst_type = stripped.split(":", 1)[1].strip()
                current_inst = classify_instrument(inst_type)
            elif stripped.startswith("Ion_mode:"):
                mode = stripped.split(":", 1)[1].strip().upper()
                current_pol = "negative" if "NEG" in mode else "positive"

            current_lines.append(line)

            # Empty line = end of spectrum block
            if stripped == "" and current_lines:
                key = (current_inst, current_pol)
                if key not in handles:
                    fname = f"massbank_{current_inst}_{current_pol}.msp"
                    handles[key] = open(
                        os.path.join(out_dir, fname), "w", encoding="utf-8"
                    )
                    counts[key] = 0

                handles[key].writelines(current_lines)
                counts[key] += 1
                current_lines = []
                current_inst = "other"
                current_pol = "positive"

    # Flush remaining
    if current_lines:
        key = (current_inst, current_pol)
        if key not in handles:
            fname = f"massbank_{current_inst}_{current_pol}.msp"
            handles[key] = open(
                os.path.join(out_dir, fname), "w", encoding="utf-8"
            )
            counts[key] = 0
        handles[key].writelines(current_lines)
        counts[key] += 1

    for h in handles.values():
        h.close()

    total = sum(counts.values())
    print(f"  MassBank split: {total} spectra -> {len(counts)} files")
    for k, c in sorted(counts.items()):
        print(f"    massbank_{k[0]}_{k[1]}.msp: {c}")

    return {
        f"massbank_{k[0]}_{k[1]}.msp": {
            "source": "massbank",
            "instrument": k[0],
            "polarity": k[1],
            "count": c,
            "data_type": "experimental",
        }
        for k, c in counts.items()
    }


# ============================================================
# Stage 2: Convert MGF → MSP
# ============================================================

def mgf_to_msp(mgf_path: str, msp_path: str) -> int:
    """Convert MGF file to MSP format. Returns spectrum count."""
    count = 0
    with open(mgf_path, encoding="utf-8", errors="replace") as fin, \
         open(msp_path, "w", encoding="utf-8") as fout:

        in_ions = False
        meta = {}
        peaks = []

        for line in fin:
            stripped = line.strip()

            if stripped == "BEGIN IONS":
                in_ions = True
                meta = {}
                peaks = []
                continue

            if stripped == "END IONS":
                in_ions = False
                # Write MSP block
                name = meta.get("NAME", meta.get("TITLE", f"Unknown_{count+1}"))
                fout.write(f"Name: {name}\n")
                if "PEPMASS" in meta:
                    mz = meta["PEPMASS"].split()[0]
                    fout.write(f"PrecursorMZ: {mz}\n")
                if "PRECURSOR_TYPE" in meta or "ADDUCT" in meta:
                    fout.write(f"Precursor_type: {meta.get('PRECURSOR_TYPE', meta.get('ADDUCT', ''))}\n")
                if "CHARGE" in meta:
                    fout.write(f"Ion_mode: {'NEGATIVE' if '-' in meta['CHARGE'] else 'POSITIVE'}\n")
                for key in ["FORMULA", "INCHIKEY", "SMILES", "INCHI", "INSTRUMENT_TYPE",
                            "ORGANISM", "LIBRARYQUALITY", "SPECTRUMID", "SCANS"]:
                    if key in meta:
                        # Map to MSP field names
                        msp_key = {
                            "FORMULA": "Formula",
                            "INCHIKEY": "InChIKey",
                            "SMILES": "SMILES",
                            "INCHI": "InChI",
                            "INSTRUMENT_TYPE": "Instrument_type",
                            "ORGANISM": "Organism",
                            "LIBRARYQUALITY": "Library_quality",
                            "SPECTRUMID": "DB#",
                        }.get(key, key)
                        fout.write(f"{msp_key}: {meta[key]}\n")

                fout.write(f"Num Peaks: {len(peaks)}\n")
                for p in peaks:
                    fout.write(p + "\n")
                fout.write("\n")
                count += 1
                continue

            if in_ions:
                if "=" in stripped and not stripped[0].isdigit():
                    k, v = stripped.split("=", 1)
                    meta[k.strip().upper()] = v.strip()
                elif stripped and stripped[0].isdigit():
                    peaks.append(stripped)

    return count


def convert_gnps(lib_dir: str) -> dict:
    """Convert GNPS MGF files to MSP."""
    gnps_dir = os.path.join(lib_dir, "raw/gnps")
    out_dir = os.path.join(lib_dir, "converted")
    results = {}

    if not os.path.isdir(gnps_dir):
        return results

    for mgf_file in sorted(os.listdir(gnps_dir)):
        if not mgf_file.endswith(".mgf"):
            continue
        src = os.path.join(gnps_dir, mgf_file)
        # e.g. GNPS-HMDB.mgf -> gnps_hmdb_mixed.msp
        base = mgf_file.replace("GNPS-", "").replace(".mgf", "").lower()
        out_name = f"gnps_{base}_mixed.msp"
        out_path = os.path.join(out_dir, out_name)

        print(f"  Converting {mgf_file} -> {out_name}...")
        count = mgf_to_msp(src, out_path)
        print(f"    {count} spectra")

        results[out_name] = {
            "source": "gnps",
            "instrument": "mixed",
            "polarity": "both",
            "count": count,
            "data_type": "experimental",
        }

    return results


def convert_msnlib(lib_dir: str) -> dict:
    """Convert MSnLib MGF files to MSP."""
    msnlib_dir = os.path.join(lib_dir, "raw/msnlib")
    out_dir = os.path.join(lib_dir, "converted")
    results = {}

    if not os.path.isdir(msnlib_dir):
        return results

    for mgf_file in sorted(os.listdir(msnlib_dir)):
        if not mgf_file.endswith(".mgf"):
            continue
        src = os.path.join(msnlib_dir, mgf_file)
        # e.g. 20241003_enamdisc_pos_ms2.mgf -> msnlib_enamdisc_positive.msp
        m = re.match(r"\d+_(\w+)_(pos|neg)_ms2\.mgf", mgf_file)
        if m:
            compound_class = m.group(1)
            polarity = "positive" if m.group(2) == "pos" else "negative"
        else:
            compound_class = mgf_file.replace(".mgf", "")
            polarity = "both"

        out_name = f"msnlib_{compound_class}_{polarity}.msp"
        out_path = os.path.join(out_dir, out_name)

        print(f"  Converting {mgf_file} -> {out_name}...")
        count = mgf_to_msp(src, out_path)
        print(f"    {count} spectra")

        results[out_name] = {
            "source": "msnlib",
            "instrument": "mixed",
            "polarity": polarity,
            "count": count,
            "data_type": "experimental",
        }

    return results


def convert_isdb(lib_dir: str) -> dict:
    """Convert ISDB MGF to MSP."""
    src = os.path.join(lib_dir, "raw/isdb/isdb_pos.mgf")
    out_dir = os.path.join(lib_dir, "converted")
    results = {}

    if not os.path.exists(src):
        return results

    out_name = "isdb_positive.msp"
    out_path = os.path.join(out_dir, out_name)
    print(f"  Converting isdb_pos.mgf -> {out_name}...")
    count = mgf_to_msp(src, out_path)
    print(f"    {count} spectra")

    results[out_name] = {
        "source": "isdb",
        "instrument": "predicted",
        "polarity": "positive",
        "count": count,
        "data_type": "predicted",
    }
    return results


# ============================================================
# Stage 3: Copy/rename MSP files (NORMAN, MS-DIAL)
# ============================================================

def copy_msp_files(lib_dir: str) -> dict:
    """Copy NORMAN and MS-DIAL MSP files to converted/."""
    out_dir = os.path.join(lib_dir, "converted")
    results = {}

    # NORMAN
    norman_files = {
        "raw/norman/NORMAN_CFM-ID_MplusH.msp": ("norman_positive.msp", "positive"),
        "raw/norman/NORMAN_CFM-ID_MminusH.msp": ("norman_negative.msp", "negative"),
    }
    for src_rel, (out_name, pol) in norman_files.items():
        src = os.path.join(lib_dir, src_rel)
        if os.path.exists(src):
            import shutil
            dst = os.path.join(out_dir, out_name)
            shutil.copy2(src, dst)
            count = sum(1 for line in open(src, errors="replace") if line.strip().startswith("NAME:") or line.strip().startswith("Name:"))
            print(f"  Copied {src_rel} -> {out_name} ({count} spectra)")
            results[out_name] = {
                "source": "norman",
                "instrument": "predicted",
                "polarity": pol,
                "count": count,
                "data_type": "predicted",
            }

    # MS-DIAL
    msdial_files = {
        "raw/msdial/MSMS-Public_experimentspectra-pos-VS19.msp": ("msdial_experimental_positive.msp", "positive", "experimental"),
        "raw/msdial/MSMS-Public_experimentspectra-neg-VS19.msp": ("msdial_experimental_negative.msp", "negative", "experimental"),
        "raw/msdial/MSMS-Public_all-pos-VS19.msp": ("msdial_all_positive.msp", "positive", "mixed"),
        "raw/msdial/MSMS-Public_all-neg-VS19.msp": ("msdial_all_negative.msp", "negative", "mixed"),
    }
    for src_rel, (out_name, pol, dtype) in msdial_files.items():
        src = os.path.join(lib_dir, src_rel)
        if os.path.exists(src):
            import shutil
            dst = os.path.join(out_dir, out_name)
            shutil.copy2(src, dst)
            count = sum(1 for line in open(src, errors="replace") if line.upper().strip().startswith("NAME:"))
            print(f"  Copied {src_rel} -> {out_name} ({count} spectra)")
            results[out_name] = {
                "source": "msdial",
                "instrument": "mixed",
                "polarity": pol,
                "count": count,
                "data_type": dtype,
            }

    return results


# ============================================================
# Stage 4: Convert ReSpect txt → MSP
# ============================================================

def convert_respect(lib_dir: str) -> dict:
    """Convert ReSpect individual txt files to combined MSP."""
    respect_dir = os.path.join(lib_dir, "raw/respect/spectra")
    out_dir = os.path.join(lib_dir, "converted")
    results = {}

    if not os.path.isdir(respect_dir):
        return results

    pos_out = os.path.join(out_dir, "respect_positive.msp")
    neg_out = os.path.join(out_dir, "respect_negative.msp")
    pos_f = open(pos_out, "w", encoding="utf-8")
    neg_f = open(neg_out, "w", encoding="utf-8")
    pos_count = neg_count = 0

    for fname in sorted(os.listdir(respect_dir)):
        if not fname.endswith(".txt"):
            continue
        fpath = os.path.join(respect_dir, fname)
        try:
            with open(fpath, encoding="utf-8", errors="replace") as f:
                content = f.read()
        except Exception:
            continue

        # Parse ReSpect format
        name = formula = precursor_mz = precursor_type = inchikey = ""
        ion_mode = "POSITIVE"
        peaks = []
        in_peaks = False

        for line in content.split("\n"):
            line = line.strip()
            if line.startswith("RECORD_TITLE:"):
                name = line.split(":", 1)[1].strip()
            elif line.startswith("CH$FORMULA:"):
                formula = line.split(":", 1)[1].strip()
            elif line.startswith("CH$EXACT_MASS:"):
                pass  # We use precursor m/z instead
            elif line.startswith("CH$LINK: INCHIKEY"):
                inchikey = line.split("INCHIKEY")[1].strip()
            elif line.startswith("MS$FOCUSED_ION: PRECURSOR_M/Z"):
                precursor_mz = line.split("PRECURSOR_M/Z")[1].strip()
            elif line.startswith("MS$FOCUSED_ION: PRECURSOR_TYPE"):
                precursor_type = line.split("PRECURSOR_TYPE")[1].strip()
            elif line.startswith("AC$MASS_SPECTROMETRY: ION_MODE"):
                ion_mode = line.split("ION_MODE")[1].strip().upper()
            elif line.startswith("PK$PEAK:"):
                in_peaks = True
            elif line == "//":
                in_peaks = False
            elif in_peaks and line and line[0].isdigit():
                parts = line.split()
                if len(parts) >= 2:
                    peaks.append(f"{parts[0]} {parts[2] if len(parts) > 2 else parts[1]}")

        if not name or not peaks:
            continue

        # Write MSP
        is_neg = "NEG" in ion_mode
        out_f = neg_f if is_neg else pos_f
        out_f.write(f"Name: {name}\n")
        if precursor_mz:
            out_f.write(f"PrecursorMZ: {precursor_mz}\n")
        if precursor_type:
            out_f.write(f"Precursor_type: {precursor_type}\n")
        if formula:
            out_f.write(f"Formula: {formula}\n")
        if inchikey:
            out_f.write(f"InChIKey: {inchikey}\n")
        out_f.write(f"Ion_mode: {ion_mode}\n")
        out_f.write(f"Instrument_type: LC-ESI-ITTOF\n")
        out_f.write(f"DB#: {fname.replace('.txt', '')}\n")
        out_f.write(f"Num Peaks: {len(peaks)}\n")
        for p in peaks:
            out_f.write(p + "\n")
        out_f.write("\n")

        if is_neg:
            neg_count += 1
        else:
            pos_count += 1

    pos_f.close()
    neg_f.close()

    print(f"  ReSpect: {pos_count} positive + {neg_count} negative spectra")

    if pos_count > 0:
        results["respect_positive.msp"] = {
            "source": "respect",
            "instrument": "ion_trap",
            "polarity": "positive",
            "count": pos_count,
            "data_type": "experimental",
        }
    if neg_count > 0:
        results["respect_negative.msp"] = {
            "source": "respect",
            "instrument": "ion_trap",
            "polarity": "negative",
            "count": neg_count,
            "data_type": "experimental",
        }

    return results


# ============================================================
# Stage 5: Convert HMDB experimental XML → MSP
# ============================================================

def _load_hmdb_compound_lookup(lib_dir: str) -> dict:
    """Load HMDB compound CSV for name/formula lookup by HMDB ID."""
    csv_path = os.path.join(lib_dir, "level3_compounds/hmdb/hmdb_compounds.csv")
    lookup = {}
    if os.path.exists(csv_path):
        import csv as csv_mod
        with open(csv_path) as f:
            reader = csv_mod.DictReader(f)
            for row in reader:
                hid = row.get("hmdb_id", "")
                if hid:
                    lookup[hid] = {
                        "name": row.get("name", ""),
                        "formula": row.get("formula", ""),
                        "exact_mass": row.get("exact_mass", ""),
                    }
    return lookup


def convert_hmdb_experimental(lib_dir: str) -> dict:
    """Convert HMDB experimental MS/MS XML files to MSP."""
    hmdb_dir = os.path.join(lib_dir, "raw/hmdb/experimental")
    out_dir = os.path.join(lib_dir, "converted")
    results = {}

    if not os.path.isdir(hmdb_dir):
        return results

    # Load compound lookup for names/formulas
    compound_lookup = _load_hmdb_compound_lookup(lib_dir)
    print(f"  Loaded {len(compound_lookup)} HMDB compound records for lookup")

    pos_out = os.path.join(out_dir, "hmdb_experimental_positive.msp")
    neg_out = os.path.join(out_dir, "hmdb_experimental_negative.msp")
    pos_f = open(pos_out, "w", encoding="utf-8")
    neg_f = open(neg_out, "w", encoding="utf-8")
    pos_count = neg_count = 0
    errors = 0

    xml_files = [f for f in os.listdir(hmdb_dir) if f.endswith(".xml")]
    total = len(xml_files)
    print(f"  Converting {total} HMDB experimental XML files...")

    for i, fname in enumerate(sorted(xml_files)):
        if (i + 1) % 10000 == 0:
            print(f"    {i+1}/{total}...")

        fpath = os.path.join(hmdb_dir, fname)
        try:
            tree = ET.parse(fpath)
            root = tree.getroot()

            def find(tag):
                el = root.find(tag)
                if el is not None and el.text and el.get("nil") != "true":
                    return el.text.strip()
                return ""

            hmdb_id = find("database-id")
            ion_mode = find("ionization-mode") or "Positive"
            instrument = find("instrument-type") or ""
            adduct_type = find("adduct-type") or find("adduct") or ""
            collision_energy = find("collision-energy-voltage") or ""

            # Look up compound info from CSV
            cpd = compound_lookup.get(hmdb_id, {})
            name = cpd.get("name", hmdb_id)
            formula = cpd.get("formula", "")
            exact_mass = cpd.get("exact_mass", "")

            # Get peaks from <ms-ms-peaks>
            peaks_el = root.find("ms-ms-peaks")
            peaks = []
            if peaks_el is not None:
                for peak in peaks_el.findall("ms-ms-peak"):
                    mz_el = peak.find("mass-charge")
                    int_el = peak.find("intensity")
                    if mz_el is not None and int_el is not None:
                        mz_val = mz_el.text
                        int_val = int_el.text
                        if mz_val and int_val:
                            peaks.append(f"{mz_val} {int_val}")

            if not peaks:
                continue

            is_neg = "neg" in ion_mode.lower()
            out_f = neg_f if is_neg else pos_f

            out_f.write(f"Name: {name}\n")
            if exact_mass:
                out_f.write(f"ExactMass: {exact_mass}\n")
            if adduct_type:
                out_f.write(f"Precursor_type: {adduct_type}\n")
            if formula:
                out_f.write(f"Formula: {formula}\n")
            if hmdb_id:
                out_f.write(f"DB#: {hmdb_id}\n")
            if instrument:
                out_f.write(f"Instrument_type: {instrument}\n")
            if collision_energy:
                out_f.write(f"Collision_energy: {collision_energy}\n")
            out_f.write(f"Ion_mode: {'NEGATIVE' if is_neg else 'POSITIVE'}\n")
            out_f.write(f"Num Peaks: {len(peaks)}\n")
            for p in peaks:
                out_f.write(p + "\n")
            out_f.write("\n")

            if is_neg:
                neg_count += 1
            else:
                pos_count += 1

        except Exception:
            errors += 1

    pos_f.close()
    neg_f.close()

    print(f"  HMDB experimental: {pos_count} pos + {neg_count} neg ({errors} errors)")

    if pos_count > 0:
        results["hmdb_experimental_positive.msp"] = {
            "source": "hmdb",
            "instrument": "mixed",
            "polarity": "positive",
            "count": pos_count,
            "data_type": "experimental",
        }
    if neg_count > 0:
        results["hmdb_experimental_negative.msp"] = {
            "source": "hmdb",
            "instrument": "mixed",
            "polarity": "negative",
            "count": neg_count,
            "data_type": "experimental",
        }

    return results


# ============================================================
# Stage 6: Build SQLite Registry
# ============================================================

# Tag assignment rules per source
TAG_RULES = {
    "massbank": {
        "organism": ["universal"],
        "compound_class": ["metabolite", "drug", "environmental"],
        "confidence": ["high"],
    },
    "gnps": {
        "organism": ["universal"],
        "compound_class": ["metabolite"],
        "confidence": ["high"],
    },
    "msnlib": {
        "organism": ["universal"],
        "compound_class": ["drug", "natural_product"],
        "confidence": ["high"],
    },
    "isdb": {
        "organism": ["plant"],
        "compound_class": ["natural_product"],
        "confidence": ["low"],
    },
    "norman": {
        "organism": ["environmental"],
        "compound_class": ["environmental"],
        "confidence": ["low"],
    },
    "msdial": {
        "organism": ["universal"],
        "compound_class": ["metabolite", "lipid"],
        "confidence": ["high"],
    },
    "respect": {
        "organism": ["plant"],
        "compound_class": ["natural_product", "metabolite"],
        "confidence": ["high"],
    },
    "hmdb": {
        "organism": ["human"],
        "compound_class": ["metabolite"],
        "confidence": ["high"],
    },
}

# Override confidence for predicted data
PREDICTED_CONFIDENCE = {"predicted": "low", "mixed": "medium"}


def build_registry(lib_dir: str, file_info: dict):
    """Build SQLite registry from file_info dict."""
    db_path = os.path.join(lib_dir, "registry.db")
    csv_path = os.path.join(lib_dir, "registry.csv")

    if os.path.exists(db_path):
        os.remove(db_path)

    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    cur.execute("""
        CREATE TABLE libraries (
            id INTEGER PRIMARY KEY,
            file_path TEXT NOT NULL,
            source TEXT NOT NULL,
            data_type TEXT NOT NULL,
            polarity TEXT NOT NULL,
            format TEXT NOT NULL,
            spectra_count INTEGER,
            file_size_bytes INTEGER
        )
    """)
    cur.execute("""
        CREATE TABLE library_tags (
            library_id INTEGER REFERENCES libraries(id),
            tag_key TEXT NOT NULL,
            tag_value TEXT NOT NULL
        )
    """)
    cur.execute("CREATE INDEX idx_tags ON library_tags(tag_key, tag_value)")

    converted_dir = os.path.join(lib_dir, "converted")

    for filename, info in sorted(file_info.items()):
        file_path = f"converted/{filename}"
        full_path = os.path.join(converted_dir, filename)
        file_size = os.path.getsize(full_path) if os.path.exists(full_path) else 0

        source = info["source"]
        data_type = info["data_type"]
        polarity = info["polarity"]
        count = info["count"]
        instrument = info["instrument"]

        cur.execute(
            "INSERT INTO libraries (file_path, source, data_type, polarity, format, spectra_count, file_size_bytes) VALUES (?, ?, ?, ?, ?, ?, ?)",
            (file_path, source, data_type, polarity, "msp", count, file_size),
        )
        lib_id = cur.lastrowid

        # Instrument tag
        cur.execute(
            "INSERT INTO library_tags VALUES (?, ?, ?)",
            (lib_id, "instrument", instrument),
        )

        # Source-based tags
        rules = TAG_RULES.get(source, {})
        for tag_key, tag_values in rules.items():
            for tv in tag_values:
                # Override confidence for predicted data
                if tag_key == "confidence" and data_type in PREDICTED_CONFIDENCE:
                    tv = PREDICTED_CONFIDENCE[data_type]
                cur.execute(
                    "INSERT INTO library_tags VALUES (?, ?, ?)",
                    (lib_id, tag_key, tv),
                )

    conn.commit()

    # Export CSV for human inspection
    with open(csv_path, "w") as f:
        f.write("id,file_path,source,data_type,polarity,spectra_count,tags\n")
        for row in cur.execute("""
            SELECT l.id, l.file_path, l.source, l.data_type, l.polarity, l.spectra_count,
                   GROUP_CONCAT(lt.tag_key || '=' || lt.tag_value, '; ')
            FROM libraries l
            LEFT JOIN library_tags lt ON l.id = lt.library_id
            GROUP BY l.id
            ORDER BY l.source, l.polarity
        """):
            f.write(",".join(str(x) for x in row) + "\n")

    # Summary
    print(f"\n=== Registry Summary ===")
    print(f"  Database: {db_path}")
    total_libs = cur.execute("SELECT COUNT(*) FROM libraries").fetchone()[0]
    total_spectra = cur.execute("SELECT SUM(spectra_count) FROM libraries").fetchone()[0]
    print(f"  Libraries: {total_libs}")
    print(f"  Total spectra: {total_spectra:,}")

    print(f"\n  Tag distribution:")
    for row in cur.execute("""
        SELECT tag_key, tag_value, COUNT(*) as cnt
        FROM library_tags
        GROUP BY tag_key, tag_value
        ORDER BY tag_key, cnt DESC
    """):
        print(f"    {row[0]:20s} {row[1]:20s} {row[2]:3d} libraries")

    conn.close()


# ============================================================
# Main
# ============================================================

def main():
    parser = argparse.ArgumentParser(description="Build spectral library registry")
    parser.add_argument("--library-dir", default=DEFAULT_LIB_DIR)
    args = parser.parse_args()
    lib_dir = args.library_dir

    print(f"Building library registry in {lib_dir}")
    os.makedirs(os.path.join(lib_dir, "converted"), exist_ok=True)

    all_files = {}

    print("\n--- Stage 1: Split MassBank ---")
    all_files.update(split_massbank(lib_dir))

    print("\n--- Stage 2: Convert GNPS MGF → MSP ---")
    all_files.update(convert_gnps(lib_dir))

    print("\n--- Stage 3: Convert MSnLib MGF → MSP ---")
    all_files.update(convert_msnlib(lib_dir))

    print("\n--- Stage 4: Convert ISDB MGF → MSP ---")
    all_files.update(convert_isdb(lib_dir))

    print("\n--- Stage 5: Copy NORMAN + MS-DIAL MSP ---")
    all_files.update(copy_msp_files(lib_dir))

    print("\n--- Stage 6: Convert ReSpect → MSP ---")
    all_files.update(convert_respect(lib_dir))

    print("\n--- Stage 7: Convert HMDB experimental → MSP ---")
    all_files.update(convert_hmdb_experimental(lib_dir))

    print(f"\n--- Stage 8: Build SQLite Registry ({len(all_files)} files) ---")
    build_registry(lib_dir, all_files)

    print("\n=== Done ===")


if __name__ == "__main__":
    main()
