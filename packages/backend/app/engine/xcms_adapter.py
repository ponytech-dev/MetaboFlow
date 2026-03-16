"""XCMS engine adapter.

Communicates with the xcms-worker Docker container via HTTP
(R Plumber API or direct Rscript invocation).
"""

from __future__ import annotations

from typing import Any

import httpx

from app.config import settings
from app.engine.base import EngineAdapter, ValidationResult


class XCMSAdapter(EngineAdapter):
    """Adapter for XCMS peak detection engine."""

    def __init__(self) -> None:
        self._base_url = settings.xcms_worker_url
        self._version: str | None = None

    @property
    def engine_name(self) -> str:
        return "xcms"

    @property
    def engine_version(self) -> str:
        if self._version is None:
            return "4.4.x"  # Default until runtime detection
        return self._version

    def validate_params(self, params: dict[str, Any]) -> ValidationResult:
        result = ValidationResult()

        ppm = params.get("ppm", 15)
        if not 1 <= ppm <= 100:
            result.add_error(f"ppm must be between 1 and 100, got {ppm}")

        peakwidth = params.get("peakwidth", [5, 30])
        if len(peakwidth) != 2 or peakwidth[0] >= peakwidth[1]:
            result.add_error("peakwidth must be [min, max] with min < max")

        noise = params.get("noise", 500)
        if noise < 0:
            result.add_error("noise must be non-negative")

        min_fraction = params.get("min_fraction", 0.5)
        if not 0 < min_fraction <= 1:
            result.add_error("min_fraction must be between 0 (exclusive) and 1")

        return result

    async def run(self, input_path: str, params: dict[str, Any], output_dir: str) -> dict[str, Any]:
        """Run XCMS peak detection via xcms-worker container."""
        payload = {
            "work_dir": input_path,
            "polarity": params.get("polarity", "positive"),
            "ppm": params.get("ppm", 15),
            "peakwidth": params.get("peakwidth", [5, 30]),
            "snthresh": params.get("snthresh", 5),
            "noise": params.get("noise", 500),
            "min_fraction": params.get("min_fraction", 0.5),
            "output_dir": output_dir,
        }

        async with httpx.AsyncClient(timeout=7200) as client:
            response = await client.post(f"{self._base_url}/run_peak_detection", json=payload)
            response.raise_for_status()
            return response.json()

    def get_default_params(self) -> dict[str, Any]:
        return {
            "ppm": 15,
            "peakwidth": [5, 30],
            "snthresh": 5,
            "noise": 500,
            "min_fraction": 0.5,
            "polarity": "positive",
        }

    def get_param_schema(self) -> dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "ppm": {
                    "type": "number",
                    "title": "Mass tolerance (ppm)",
                    "default": 15,
                    "minimum": 1,
                    "maximum": 100,
                },
                "peakwidth": {
                    "type": "array",
                    "title": "Peak width range (seconds)",
                    "items": {"type": "number"},
                    "default": [5, 30],
                    "minItems": 2,
                    "maxItems": 2,
                },
                "snthresh": {
                    "type": "number",
                    "title": "Signal-to-noise threshold",
                    "default": 5,
                    "minimum": 1,
                },
                "noise": {
                    "type": "number",
                    "title": "Noise level",
                    "default": 500,
                    "minimum": 0,
                },
                "min_fraction": {
                    "type": "number",
                    "title": "Minimum sample fraction",
                    "default": 0.5,
                    "minimum": 0.01,
                    "maximum": 1.0,
                },
                "polarity": {
                    "type": "string",
                    "title": "Ionization polarity",
                    "enum": ["positive", "negative"],
                    "default": "positive",
                },
            },
        }

    async def health_check(self) -> bool:
        try:
            async with httpx.AsyncClient(timeout=5) as client:
                resp = await client.get(f"{self._base_url}/health")
                return resp.status_code == 200
        except httpx.HTTPError:
            return False
