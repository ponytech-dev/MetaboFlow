"""Tests for all engine adapters.

Covers parameter validation (valid and invalid), default params,
JSON schema structure, and registry completeness.
"""

from __future__ import annotations

import pytest

from app.engine.msdial_adapter import MSDIALAdapter
from app.engine.mzmine_adapter import MZmineAdapter
from app.engine.pyopenms_adapter import PyOpenMSAdapter
from app.engine.registry import EngineRegistry
from app.engine.xcms_adapter import XCMSAdapter


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def valid(adapter, params=None):
    """Return True if params (or empty dict) pass validation."""
    p = params if params is not None else {}
    return adapter.validate_params(p).is_valid


def errors(adapter, params):
    return adapter.validate_params(params).errors


# ---------------------------------------------------------------------------
# MZmineAdapter
# ---------------------------------------------------------------------------


class TestMZmineAdapter:
    adapter = MZmineAdapter()

    def test_default_params_are_valid(self):
        assert valid(self.adapter, self.adapter.get_default_params())

    def test_invalid_mass_detector(self):
        params = {**self.adapter.get_default_params(), "mass_detector": "unknown"}
        assert not valid(self.adapter, params)
        assert any("mass_detector" in e for e in errors(self.adapter, params))

    def test_noise_level_zero_is_invalid(self):
        params = {**self.adapter.get_default_params(), "noise_level": 0}
        assert not valid(self.adapter, params)

    def test_noise_level_negative_is_invalid(self):
        params = {**self.adapter.get_default_params(), "noise_level": -100}
        assert not valid(self.adapter, params)

    def test_mz_tolerance_below_range_is_invalid(self):
        params = {**self.adapter.get_default_params(), "mz_tolerance": 0.5}
        assert not valid(self.adapter, params)

    def test_mz_tolerance_above_range_is_invalid(self):
        params = {**self.adapter.get_default_params(), "mz_tolerance": 51}
        assert not valid(self.adapter, params)

    def test_rt_tolerance_below_range_is_invalid(self):
        params = {**self.adapter.get_default_params(), "rt_tolerance": 0}
        assert not valid(self.adapter, params)

    def test_rt_tolerance_above_range_is_invalid(self):
        params = {**self.adapter.get_default_params(), "rt_tolerance": 61}
        assert not valid(self.adapter, params)

    def test_min_duration_gte_max_duration_is_invalid(self):
        params = {
            **self.adapter.get_default_params(),
            "min_peak_duration": 30.0,
            "max_peak_duration": 30.0,
        }
        assert not valid(self.adapter, params)

    def test_exact_mass_detector_is_valid(self):
        params = {**self.adapter.get_default_params(), "mass_detector": "exact_mass"}
        assert valid(self.adapter, params)

    def test_schema_has_required_keys(self):
        schema = self.adapter.get_param_schema()
        props = schema["properties"]
        for key in (
            "mass_detector",
            "noise_level",
            "mz_tolerance",
            "rt_tolerance",
            "min_peak_height",
            "min_peak_duration",
            "max_peak_duration",
        ):
            assert key in props, f"Missing schema property: {key}"

    def test_engine_name_and_version(self):
        assert self.adapter.engine_name == "mzmine"
        assert self.adapter.engine_version == "4.3.0"


# ---------------------------------------------------------------------------
# PyOpenMSAdapter
# ---------------------------------------------------------------------------


class TestPyOpenMSAdapter:
    adapter = PyOpenMSAdapter()

    def test_default_params_are_valid(self):
        assert valid(self.adapter, self.adapter.get_default_params())

    def test_mass_error_below_range_is_invalid(self):
        params = {**self.adapter.get_default_params(), "mass_error_ppm": 0.5}
        assert not valid(self.adapter, params)

    def test_mass_error_above_range_is_invalid(self):
        params = {**self.adapter.get_default_params(), "mass_error_ppm": 101}
        assert not valid(self.adapter, params)

    def test_peak_width_min_gte_max_is_invalid(self):
        params = {
            **self.adapter.get_default_params(),
            "peak_width_min": 60.0,
            "peak_width_max": 60.0,
        }
        assert not valid(self.adapter, params)

    def test_peak_width_min_gt_max_is_invalid(self):
        params = {
            **self.adapter.get_default_params(),
            "peak_width_min": 70.0,
            "peak_width_max": 60.0,
        }
        assert not valid(self.adapter, params)

    def test_signal_to_noise_zero_is_invalid(self):
        params = {**self.adapter.get_default_params(), "signal_to_noise": 0}
        assert not valid(self.adapter, params)

    def test_negative_intensity_threshold_is_invalid(self):
        params = {**self.adapter.get_default_params(), "intensity_threshold": -1}
        assert not valid(self.adapter, params)

    def test_zero_intensity_threshold_is_valid(self):
        # Zero threshold is allowed (non-negative)
        params = {**self.adapter.get_default_params(), "intensity_threshold": 0}
        assert valid(self.adapter, params)

    def test_chrom_fwhm_zero_is_invalid(self):
        params = {**self.adapter.get_default_params(), "chrom_fwhm": 0}
        assert not valid(self.adapter, params)

    def test_schema_has_required_keys(self):
        schema = self.adapter.get_param_schema()
        props = schema["properties"]
        for key in (
            "mass_error_ppm",
            "peak_width_min",
            "peak_width_max",
            "signal_to_noise",
            "intensity_threshold",
            "chrom_fwhm",
        ):
            assert key in props, f"Missing schema property: {key}"

    def test_engine_name_and_version(self):
        assert self.adapter.engine_name == "pyopenms"
        assert self.adapter.engine_version == "3.2.0"

    @pytest.mark.asyncio
    async def test_health_check_returns_true(self):
        # pyOpenMS is in-process; health_check always returns True
        assert await self.adapter.health_check() is True

    @pytest.mark.asyncio
    async def test_run_returns_dict_with_expected_keys(self):
        result = await self.adapter.run("/fake/input", {}, "/fake/output")
        assert isinstance(result, dict)
        assert result["engine"] == "pyopenms"
        assert "status" in result


# ---------------------------------------------------------------------------
# MSDIALAdapter
# ---------------------------------------------------------------------------


class TestMSDIALAdapter:
    adapter = MSDIALAdapter()

    def test_default_params_are_valid(self):
        assert valid(self.adapter, self.adapter.get_default_params())

    def test_ms1_tolerance_zero_is_invalid(self):
        params = {**self.adapter.get_default_params(), "ms1_tolerance": 0}
        assert not valid(self.adapter, params)

    def test_ms2_tolerance_negative_is_invalid(self):
        params = {**self.adapter.get_default_params(), "ms2_tolerance": -0.01}
        assert not valid(self.adapter, params)

    def test_minimum_peak_height_zero_is_invalid(self):
        params = {**self.adapter.get_default_params(), "minimum_peak_height": 0}
        assert not valid(self.adapter, params)

    def test_invalid_smoothing_method(self):
        params = {**self.adapter.get_default_params(), "smoothing_method": "gaussian"}
        assert not valid(self.adapter, params)
        assert any("smoothing_method" in e for e in errors(self.adapter, params))

    def test_all_valid_smoothing_methods(self):
        for method in (
            "linear_weighted_moving_average",
            "savitzky_golay",
            "binomial",
        ):
            params = {**self.adapter.get_default_params(), "smoothing_method": method}
            assert valid(self.adapter, params), f"Expected valid for method={method}"

    def test_smoothing_level_out_of_range(self):
        for bad in (0, 11):
            params = {**self.adapter.get_default_params(), "smoothing_level": bad}
            assert not valid(self.adapter, params), f"Expected invalid for level={bad}"

    def test_smoothing_level_boundary_values(self):
        for good in (1, 10):
            params = {**self.adapter.get_default_params(), "smoothing_level": good}
            assert valid(self.adapter, params), f"Expected valid for level={good}"

    def test_alignment_tolerance_rt_zero_is_invalid(self):
        params = {**self.adapter.get_default_params(), "alignment_tolerance_rt": 0}
        assert not valid(self.adapter, params)

    def test_schema_has_required_keys(self):
        schema = self.adapter.get_param_schema()
        props = schema["properties"]
        for key in (
            "ms1_tolerance",
            "ms2_tolerance",
            "minimum_peak_height",
            "mass_slice_width",
            "smoothing_method",
            "smoothing_level",
            "minimum_peak_width",
            "alignment_tolerance_rt",
        ):
            assert key in props, f"Missing schema property: {key}"

    def test_engine_name_and_version(self):
        assert self.adapter.engine_name == "msdial"
        assert self.adapter.engine_version == "5.3.0"


# ---------------------------------------------------------------------------
# Registry
# ---------------------------------------------------------------------------


class TestEngineRegistry:
    def test_registry_contains_all_five_engines(self):
        registry = EngineRegistry()
        names = {e["name"] for e in registry.list_engines()}
        assert names == {"xcms", "stats", "mzmine", "pyopenms", "msdial"}

    def test_get_existing_engine_returns_adapter(self):
        registry = EngineRegistry()
        for name in ("xcms", "stats", "mzmine", "pyopenms", "msdial"):
            adapter = registry.get(name)
            assert adapter is not None, f"Engine '{name}' not found in registry"
            assert adapter.engine_name == name

    def test_get_unknown_engine_returns_none(self):
        registry = EngineRegistry()
        assert registry.get("nonexistent") is None

    def test_list_engines_returns_name_and_version(self):
        registry = EngineRegistry()
        for entry in registry.list_engines():
            assert "name" in entry
            assert "version" in entry
            assert isinstance(entry["name"], str)
            assert isinstance(entry["version"], str)

    def test_register_custom_adapter(self):
        registry = EngineRegistry()

        class _DummyAdapter(XCMSAdapter):
            @property
            def engine_name(self) -> str:
                return "dummy"

        registry.register(_DummyAdapter())
        assert registry.get("dummy") is not None
