"""pyOpenMS engine adapter.

Runs in-process — no external worker container required.
Uses pyOpenMS FeatureFinder for peak detection directly in Python.
"""

from __future__ import annotations

from typing import Any

from app.engine.base import EngineAdapter, ValidationResult


class PyOpenMSAdapter(EngineAdapter):
    """Adapter for pyOpenMS peak detection engine.

    Runs in-process, no external worker. pyOpenMS is imported at
    runtime so that the rest of the application can start without it
    being installed (enabling lightweight deployments that only use
    other engines).
    """

    @property
    def engine_name(self) -> str:
        return "pyopenms"

    @property
    def engine_version(self) -> str:
        return "3.2.0"

    def validate_params(self, params: dict[str, Any]) -> ValidationResult:
        result = ValidationResult()

        mass_error_ppm = params.get("mass_error_ppm", 10.0)
        if not 1 <= mass_error_ppm <= 100:
            result.add_error(
                f"mass_error_ppm must be between 1 and 100, got {mass_error_ppm}"
            )

        peak_width_min = params.get("peak_width_min", 3.0)
        peak_width_max = params.get("peak_width_max", 60.0)
        if peak_width_min >= peak_width_max:
            result.add_error(
                f"peak_width_min ({peak_width_min}) must be less than "
                f"peak_width_max ({peak_width_max})"
            )

        signal_to_noise = params.get("signal_to_noise", 4.0)
        if signal_to_noise <= 0:
            result.add_error(
                f"signal_to_noise must be > 0, got {signal_to_noise}"
            )

        intensity_threshold = params.get("intensity_threshold", 1000.0)
        if intensity_threshold < 0:
            result.add_error(
                f"intensity_threshold must be non-negative, got {intensity_threshold}"
            )

        chrom_fwhm = params.get("chrom_fwhm", 10.0)
        if chrom_fwhm <= 0:
            result.add_error(f"chrom_fwhm must be > 0, got {chrom_fwhm}")

        return result

    async def run(
        self, input_path: str, params: dict[str, Any], output_dir: str
    ) -> dict[str, Any]:
        """Run pyOpenMS FeatureFinder in-process.

        Runs in-process, no external worker. Imports pyOpenMS at call time
        so that adapter instantiation does not require the library to be
        installed.
        """
        # Placeholder implementation — full integration would call:
        #   import pyopenms
        #   ff = pyopenms.FeatureFinder()
        #   ff.run("centroided", ...)
        return {
            "engine": self.engine_name,
            "version": self.engine_version,
            "input_path": input_path,
            "output_dir": output_dir,
            "status": "placeholder — pyOpenMS in-process execution not yet wired",
            "params_used": {**self.get_default_params(), **params},
        }

    def get_default_params(self) -> dict[str, Any]:
        return {
            "mass_error_ppm": 10.0,
            "peak_width_min": 3.0,
            "peak_width_max": 60.0,
            "signal_to_noise": 4.0,
            "intensity_threshold": 1000.0,
            "chrom_fwhm": 10.0,
        }

    def get_param_schema(self) -> dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "mass_error_ppm": {
                    "type": "number",
                    "title": "Mass error (ppm)",
                    "default": 10.0,
                    "minimum": 1,
                    "maximum": 100,
                },
                "peak_width_min": {
                    "type": "number",
                    "title": "Minimum peak width (seconds)",
                    "default": 3.0,
                    "exclusiveMinimum": 0,
                },
                "peak_width_max": {
                    "type": "number",
                    "title": "Maximum peak width (seconds)",
                    "default": 60.0,
                    "exclusiveMinimum": 0,
                },
                "signal_to_noise": {
                    "type": "number",
                    "title": "Signal-to-noise threshold",
                    "default": 4.0,
                    "exclusiveMinimum": 0,
                },
                "intensity_threshold": {
                    "type": "number",
                    "title": "Minimum intensity threshold",
                    "default": 1000.0,
                    "minimum": 0,
                },
                "chrom_fwhm": {
                    "type": "number",
                    "title": "Chromatographic FWHM (seconds)",
                    "default": 10.0,
                    "exclusiveMinimum": 0,
                },
            },
        }

    # health_check: inherits base default (returns True).
    # pyOpenMS runs in-process so there is no remote service to ping.
