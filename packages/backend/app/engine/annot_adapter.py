"""Annotation engine adapter (annot-worker / matchms)."""

from __future__ import annotations

from typing import Any

import httpx

from app.config import settings
from app.engine.base import EngineAdapter, ValidationResult


class AnnotWorkerAdapter(EngineAdapter):
    """Adapter for annot-worker MS2 spectral matching service."""

    def __init__(self) -> None:
        self._base_url = settings.annot_worker_url
        self._version: str | None = None

    @property
    def engine_name(self) -> str:
        return "annot"

    @property
    def engine_version(self) -> str:
        if self._version is None:
            return "matchms-0.32.x"
        return self._version

    def validate_params(self, params: dict[str, Any]) -> ValidationResult:
        result = ValidationResult()
        min_score = params.get("ms2_min_score", 0.7)
        if not 0 < min_score <= 1:
            result.add_error(f"ms2_min_score must be between 0 and 1, got {min_score}")
        tolerance = params.get("ms2_tolerance_da", 0.02)
        if not 0 < tolerance <= 1:
            result.add_error(f"ms2_tolerance_da must be between 0 and 1, got {tolerance}")
        return result

    async def run(
        self, input_path: str, params: dict[str, Any], output_dir: str
    ) -> dict[str, Any]:
        """Run MS2 annotation via annot-worker container."""
        payload = {
            "spectra": params.get("spectra", []),
            "tag_filter": params.get("tag_filter", {}),
            "polarity": params.get("polarity", "positive"),
            "ms2_tolerance_da": params.get("ms2_tolerance_da", 0.02),
            "min_score": params.get("ms2_min_score", 0.7),
            "method": params.get("ms2_method", "CosineGreedy"),
            "max_matches": params.get("max_matches", 1),
        }

        async with httpx.AsyncClient(timeout=600) as client:
            response = await client.post(f"{self._base_url}/annotate", json=payload)
            response.raise_for_status()
            return response.json()

    async def get_registry(self) -> list[dict[str, Any]]:
        """Fetch library registry from annot-worker."""
        async with httpx.AsyncClient(timeout=30) as client:
            response = await client.get(f"{self._base_url}/registry")
            response.raise_for_status()
            return response.json()

    async def get_tags(self) -> dict[str, list[str]]:
        """Fetch available tag dimensions from annot-worker."""
        async with httpx.AsyncClient(timeout=30) as client:
            response = await client.get(f"{self._base_url}/registry/tags")
            response.raise_for_status()
            return response.json()

    def get_default_params(self) -> dict[str, Any]:
        return {
            "ms2_tolerance_da": 0.02,
            "ms2_min_score": 0.7,
            "ms2_method": "CosineGreedy",
            "tag_filter": {
                "instrument": [],
                "organism": [],
                "compound_class": [],
                "confidence": ["high", "medium", "low"],
            },
        }

    def get_param_schema(self) -> dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "ms2_tolerance_da": {
                    "type": "number",
                    "title": "MS2 tolerance (Da)",
                    "default": 0.02,
                    "minimum": 0.001,
                    "maximum": 1.0,
                },
                "ms2_min_score": {
                    "type": "number",
                    "title": "Minimum cosine score",
                    "default": 0.7,
                    "minimum": 0.1,
                    "maximum": 1.0,
                },
                "ms2_method": {
                    "type": "string",
                    "title": "Similarity method",
                    "enum": ["CosineGreedy", "ModifiedCosine", "CosineHungarian"],
                    "default": "CosineGreedy",
                },
                "tag_filter": {
                    "type": "object",
                    "title": "Library tag filter",
                    "properties": {
                        "instrument": {
                            "type": "array",
                            "items": {"type": "string"},
                            "title": "Instrument type",
                        },
                        "organism": {
                            "type": "array",
                            "items": {"type": "string"},
                            "title": "Organism",
                        },
                        "compound_class": {
                            "type": "array",
                            "items": {"type": "string"},
                            "title": "Compound class",
                        },
                        "confidence": {
                            "type": "array",
                            "items": {"type": "string"},
                            "title": "Confidence level",
                        },
                    },
                },
            },
        }

    async def health_check(self) -> bool:
        try:
            async with httpx.AsyncClient(timeout=5) as client:
                resp = await client.get(f"{self._base_url}/health")
                if resp.status_code == 200:
                    data = resp.json()
                    self._version = f"matchms-{data.get('matchms_version', 'unknown')}"
                    return True
                return False
        except httpx.HTTPError:
            return False
