"""SIRIUS/CSI:FingerID engine adapter."""

from __future__ import annotations

from typing import Any

import httpx

from app.config import settings
from app.engine.base import EngineAdapter, ValidationResult


class SiriusWorkerAdapter(EngineAdapter):
    """Adapter for sirius-worker structure prediction service."""

    def __init__(self) -> None:
        self._base_url = settings.sirius_worker_url
        self._version: str | None = None

    @property
    def engine_name(self) -> str:
        return "sirius"

    @property
    def engine_version(self) -> str:
        return self._version or "sirius-6.x"

    def validate_params(self, params: dict[str, Any]) -> ValidationResult:
        result = ValidationResult()
        db = params.get("database", "bio")
        valid_dbs = {"bio", "pubchem", "kegg", "hmdb"}
        if db not in valid_dbs:
            result.add_error(f"database must be one of {valid_dbs}, got {db}")
        return result

    async def run(
        self, input_path: str, params: dict[str, Any], output_dir: str
    ) -> dict[str, Any]:
        """Run SIRIUS structure prediction via sirius-worker container."""
        payload = {
            "spectra": params.get("spectra", []),
            "database": params.get("database", "bio"),
            "max_candidates": params.get("max_candidates", 5),
            "instrument": params.get("instrument", "orbitrap"),
        }

        async with httpx.AsyncClient(timeout=600) as client:
            response = await client.post(f"{self._base_url}/predict", json=payload)
            response.raise_for_status()
            return response.json()

    def get_default_params(self) -> dict[str, Any]:
        return {
            "database": "bio",
            "max_candidates": 5,
            "instrument": "orbitrap",
        }

    def get_param_schema(self) -> dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "database": {
                    "type": "string",
                    "title": "Structure database",
                    "enum": ["bio", "pubchem", "kegg", "hmdb"],
                    "default": "bio",
                },
                "max_candidates": {
                    "type": "integer",
                    "title": "Max candidates",
                    "default": 5,
                    "minimum": 1,
                    "maximum": 50,
                },
                "instrument": {
                    "type": "string",
                    "title": "Instrument type",
                    "enum": ["orbitrap", "qtof", "fticr"],
                    "default": "orbitrap",
                },
            },
        }

    async def health_check(self) -> bool:
        try:
            async with httpx.AsyncClient(timeout=5) as client:
                resp = await client.get(f"{self._base_url}/health")
                if resp.status_code == 200:
                    data = resp.json()
                    self._version = f"sirius-{data.get('sirius_version', 'unknown')}"
                    return True
                return False
        except httpx.HTTPError:
            return False
