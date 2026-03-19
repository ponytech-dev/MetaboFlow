"""Query the spectral library SQLite registry."""

from __future__ import annotations

import sqlite3
from collections import defaultdict

from app.config import settings
from app.models import LibraryInfo, TagFilter


def get_connection() -> sqlite3.Connection:
    return sqlite3.connect(settings.registry_db)


def select_libraries(
    tag_filter: TagFilter,
    polarity: str = "positive",
) -> list[str]:
    """Select library file paths matching the tag filter.

    Within a dimension (e.g. instrument), values are OR'd.
    Across dimensions, filters are AND'd.
    Empty filter list = no filtering on that dimension.
    """
    conn = get_connection()
    cur = conn.cursor()

    # Start with all libraries matching polarity
    query = """
        SELECT id, file_path FROM libraries
        WHERE polarity IN (?, 'both')
    """
    params: list = [polarity]

    # For each non-empty tag filter, add an intersect condition
    filters = {
        "instrument": tag_filter.instrument,
        "organism": tag_filter.organism,
        "compound_class": tag_filter.compound_class,
        "confidence": tag_filter.confidence,
    }

    for tag_key, tag_values in filters.items():
        if not tag_values:
            continue
        placeholders = ",".join("?" * len(tag_values))
        query += f"""
            AND id IN (
                SELECT library_id FROM library_tags
                WHERE tag_key = ? AND tag_value IN ({placeholders})
            )
        """
        params.append(tag_key)
        params.extend(tag_values)

    rows = cur.execute(query, params).fetchall()
    conn.close()

    return [row[1] for row in rows]


def list_all_libraries() -> list[LibraryInfo]:
    """List all libraries with their tags."""
    conn = get_connection()
    cur = conn.cursor()

    libs = {}
    for row in cur.execute(
        "SELECT id, file_path, source, data_type, polarity, spectra_count FROM libraries"
    ):
        libs[row[0]] = LibraryInfo(
            id=row[0],
            file_path=row[1],
            source=row[2],
            data_type=row[3],
            polarity=row[4],
            spectra_count=row[5],
            tags={},
        )

    for row in cur.execute("SELECT library_id, tag_key, tag_value FROM library_tags"):
        lib_id, key, val = row
        if lib_id in libs:
            if key not in libs[lib_id].tags:
                libs[lib_id].tags[key] = []
            libs[lib_id].tags[key].append(val)

    conn.close()
    return list(libs.values())


def list_tag_values() -> dict[str, list[str]]:
    """List all distinct tag keys and their possible values."""
    conn = get_connection()
    cur = conn.cursor()

    result: dict[str, list[str]] = defaultdict(list)
    for row in cur.execute(
        "SELECT DISTINCT tag_key, tag_value FROM library_tags ORDER BY tag_key, tag_value"
    ):
        result[row[0]].append(row[1])

    conn.close()
    return dict(result)
