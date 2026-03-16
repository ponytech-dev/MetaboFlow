"""MZmine engine adapter.

Communicates with the mzmine-worker Docker container via HTTP.
MZmine 4 is invoked in batch mode using an XML batch file.
"""

from __future__ import annotations

from typing import Any

import httpx

from app.config import settings
from app.engine.base import EngineAdapter, ValidationResult

_VALID_MASS_DETECTORS = {"centroid", "exact_mass"}


class MZmineAdapter(EngineAdapter):
    """Adapter for MZmine 4 peak detection engine (batch XML mode)."""

    def __init__(self) -> None:
        self._base_url = settings.mzmine_worker_url

    @property
    def engine_name(self) -> str:
        return "mzmine"

    @property
    def engine_version(self) -> str:
        return "4.3.0"

    def validate_params(self, params: dict[str, Any]) -> ValidationResult:
        result = ValidationResult()

        mass_detector = params.get("mass_detector", "centroid")
        if mass_detector not in _VALID_MASS_DETECTORS:
            result.add_error(
                f"mass_detector must be one of {sorted(_VALID_MASS_DETECTORS)}, "
                f"got '{mass_detector}'"
            )

        noise_level = params.get("noise_level", 1000.0)
        if noise_level <= 0:
            result.add_error(f"noise_level must be > 0, got {noise_level}")

        mz_tolerance = params.get("mz_tolerance", 10.0)
        if not 1 <= mz_tolerance <= 50:
            result.add_error(
                f"mz_tolerance must be between 1 and 50 ppm, got {mz_tolerance}"
            )

        rt_tolerance = params.get("rt_tolerance", 10.0)
        if not 1 <= rt_tolerance <= 60:
            result.add_error(
                f"rt_tolerance must be between 1 and 60 seconds, got {rt_tolerance}"
            )

        min_peak_height = params.get("min_peak_height", 5000.0)
        if min_peak_height <= 0:
            result.add_error(f"min_peak_height must be > 0, got {min_peak_height}")

        min_peak_duration = params.get("min_peak_duration", 3.0)
        max_peak_duration = params.get("max_peak_duration", 60.0)
        if min_peak_duration >= max_peak_duration:
            result.add_error(
                f"min_peak_duration ({min_peak_duration}) must be less than "
                f"max_peak_duration ({max_peak_duration})"
            )

        return result

    async def run(
        self, input_path: str, params: dict[str, Any], output_dir: str
    ) -> dict[str, Any]:
        """Run MZmine peak detection via mzmine-worker container.

        The worker receives the batch parameters and constructs the MZmine
        batch XML internally before invoking the MZmine CLI.
        """
        payload = {
            "input_path": input_path,
            "output_dir": output_dir,
            "mass_detector": params.get("mass_detector", "centroid"),
            "noise_level": params.get("noise_level", 1000.0),
            "mz_tolerance": params.get("mz_tolerance", 10.0),
            "rt_tolerance": params.get("rt_tolerance", 10.0),
            "min_peak_height": params.get("min_peak_height", 5000.0),
            "min_peak_duration": params.get("min_peak_duration", 3.0),
            "max_peak_duration": params.get("max_peak_duration", 60.0),
        }

        async with httpx.AsyncClient(timeout=7200) as client:
            response = await client.post(
                f"{self._base_url}/run_peak_detection", json=payload
            )
            response.raise_for_status()
            return response.json()

    def get_default_params(self) -> dict[str, Any]:
        return {
            "mass_detector": "centroid",
            "noise_level": 1000.0,
            "mz_tolerance": 10.0,
            "rt_tolerance": 10.0,
            "min_peak_height": 5000.0,
            "min_peak_duration": 3.0,
            "max_peak_duration": 60.0,
        }

    def get_param_schema(self) -> dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "mass_detector": {
                    "type": "string",
                    "title": "Mass detector algorithm",
                    "enum": ["centroid", "exact_mass"],
                    "default": "centroid",
                },
                "noise_level": {
                    "type": "number",
                    "title": "Noise level (intensity units)",
                    "default": 1000.0,
                    "exclusiveMinimum": 0,
                },
                "mz_tolerance": {
                    "type": "number",
                    "title": "m/z tolerance (ppm)",
                    "default": 10.0,
                    "minimum": 1,
                    "maximum": 50,
                },
                "rt_tolerance": {
                    "type": "number",
                    "title": "RT tolerance (seconds)",
                    "default": 10.0,
                    "minimum": 1,
                    "maximum": 60,
                },
                "min_peak_height": {
                    "type": "number",
                    "title": "Minimum peak height (intensity units)",
                    "default": 5000.0,
                    "exclusiveMinimum": 0,
                },
                "min_peak_duration": {
                    "type": "number",
                    "title": "Minimum peak duration (seconds)",
                    "default": 3.0,
                    "exclusiveMinimum": 0,
                },
                "max_peak_duration": {
                    "type": "number",
                    "title": "Maximum peak duration (seconds)",
                    "default": 60.0,
                    "exclusiveMinimum": 0,
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
