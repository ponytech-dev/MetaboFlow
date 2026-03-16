"""MS-DIAL engine adapter.

Communicates with the msdial-worker Docker container via HTTP.
MS-DIAL 5 is invoked via its console application interface.
"""

from __future__ import annotations

from typing import Any

import httpx

from app.config import settings
from app.engine.base import EngineAdapter, ValidationResult

_VALID_SMOOTHING_METHODS = {
    "linear_weighted_moving_average",
    "savitzky_golay",
    "binomial",
}


class MSDIALAdapter(EngineAdapter):
    """Adapter for MS-DIAL 5 peak detection and alignment engine."""

    def __init__(self) -> None:
        self._base_url = settings.msdial_worker_url

    @property
    def engine_name(self) -> str:
        return "msdial"

    @property
    def engine_version(self) -> str:
        return "5.3.0"

    def validate_params(self, params: dict[str, Any]) -> ValidationResult:
        result = ValidationResult()

        ms1_tolerance = params.get("ms1_tolerance", 0.01)
        if ms1_tolerance <= 0:
            result.add_error(
                f"ms1_tolerance must be > 0, got {ms1_tolerance}"
            )

        ms2_tolerance = params.get("ms2_tolerance", 0.025)
        if ms2_tolerance <= 0:
            result.add_error(
                f"ms2_tolerance must be > 0, got {ms2_tolerance}"
            )

        minimum_peak_height = params.get("minimum_peak_height", 1000)
        if minimum_peak_height <= 0:
            result.add_error(
                f"minimum_peak_height must be > 0, got {minimum_peak_height}"
            )

        mass_slice_width = params.get("mass_slice_width", 0.1)
        if mass_slice_width <= 0:
            result.add_error(
                f"mass_slice_width must be > 0, got {mass_slice_width}"
            )

        smoothing_method = params.get(
            "smoothing_method", "linear_weighted_moving_average"
        )
        if smoothing_method not in _VALID_SMOOTHING_METHODS:
            result.add_error(
                f"smoothing_method must be one of "
                f"{sorted(_VALID_SMOOTHING_METHODS)}, got '{smoothing_method}'"
            )

        smoothing_level = params.get("smoothing_level", 3)
        if not 1 <= smoothing_level <= 10:
            result.add_error(
                f"smoothing_level must be between 1 and 10, got {smoothing_level}"
            )

        minimum_peak_width = params.get("minimum_peak_width", 5)
        if minimum_peak_width <= 0:
            result.add_error(
                f"minimum_peak_width must be > 0, got {minimum_peak_width}"
            )

        alignment_tolerance_rt = params.get("alignment_tolerance_rt", 0.1)
        if alignment_tolerance_rt <= 0:
            result.add_error(
                f"alignment_tolerance_rt must be > 0, got {alignment_tolerance_rt}"
            )

        return result

    async def run(
        self, input_path: str, params: dict[str, Any], output_dir: str
    ) -> dict[str, Any]:
        """Run MS-DIAL processing via msdial-worker container."""
        payload = {
            "input_path": input_path,
            "output_dir": output_dir,
            "ms1_tolerance": params.get("ms1_tolerance", 0.01),
            "ms2_tolerance": params.get("ms2_tolerance", 0.025),
            "minimum_peak_height": params.get("minimum_peak_height", 1000),
            "mass_slice_width": params.get("mass_slice_width", 0.1),
            "smoothing_method": params.get(
                "smoothing_method", "linear_weighted_moving_average"
            ),
            "smoothing_level": params.get("smoothing_level", 3),
            "minimum_peak_width": params.get("minimum_peak_width", 5),
            "alignment_tolerance_rt": params.get("alignment_tolerance_rt", 0.1),
        }

        async with httpx.AsyncClient(timeout=7200) as client:
            response = await client.post(
                f"{self._base_url}/run_peak_detection", json=payload
            )
            response.raise_for_status()
            return response.json()

    def get_default_params(self) -> dict[str, Any]:
        return {
            "ms1_tolerance": 0.01,
            "ms2_tolerance": 0.025,
            "minimum_peak_height": 1000,
            "mass_slice_width": 0.1,
            "smoothing_method": "linear_weighted_moving_average",
            "smoothing_level": 3,
            "minimum_peak_width": 5,
            "alignment_tolerance_rt": 0.1,
        }

    def get_param_schema(self) -> dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "ms1_tolerance": {
                    "type": "number",
                    "title": "MS1 mass tolerance (Da)",
                    "default": 0.01,
                    "exclusiveMinimum": 0,
                },
                "ms2_tolerance": {
                    "type": "number",
                    "title": "MS2 mass tolerance (Da)",
                    "default": 0.025,
                    "exclusiveMinimum": 0,
                },
                "minimum_peak_height": {
                    "type": "number",
                    "title": "Minimum peak height (intensity units)",
                    "default": 1000,
                    "exclusiveMinimum": 0,
                },
                "mass_slice_width": {
                    "type": "number",
                    "title": "Mass slice width (Da)",
                    "default": 0.1,
                    "exclusiveMinimum": 0,
                },
                "smoothing_method": {
                    "type": "string",
                    "title": "Chromatogram smoothing method",
                    "enum": [
                        "linear_weighted_moving_average",
                        "savitzky_golay",
                        "binomial",
                    ],
                    "default": "linear_weighted_moving_average",
                },
                "smoothing_level": {
                    "type": "integer",
                    "title": "Smoothing level",
                    "default": 3,
                    "minimum": 1,
                    "maximum": 10,
                },
                "minimum_peak_width": {
                    "type": "integer",
                    "title": "Minimum peak width (scans)",
                    "default": 5,
                    "exclusiveMinimum": 0,
                },
                "alignment_tolerance_rt": {
                    "type": "number",
                    "title": "RT alignment tolerance (minutes)",
                    "default": 0.1,
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
