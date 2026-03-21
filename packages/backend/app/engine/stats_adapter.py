"""Statistics engine adapter.

Communicates with the stats-worker Docker container for
differential analysis (limma), PCA, and pathway analysis.
"""

from __future__ import annotations

from typing import Any

import httpx

from app.config import settings
from app.engine.base import EngineAdapter, ValidationResult


class StatsAdapter(EngineAdapter):
    """Adapter for statistical analysis engine (limma + scipy)."""

    def __init__(self) -> None:
        self._base_url = settings.stats_worker_url

    @property
    def engine_name(self) -> str:
        return "stats"

    @property
    def engine_version(self) -> str:
        return "limma-3.62/scipy-1.14"

    def validate_params(self, params: dict[str, Any]) -> ValidationResult:
        result = ValidationResult()

        fc = params.get("fc_cutoff", 1.5)
        if fc <= 0:
            result.add_error("fc_cutoff must be positive")

        p = params.get("p_value_cutoff", 0.05)
        if not 0 < p <= 1:
            result.add_error("p_value_cutoff must be between 0 and 1")

        return result

    async def run(self, input_path: str, params: dict[str, Any], output_dir: str) -> dict[str, Any]:
        payload = {
            "metabodata_path": input_path,
            "analysis_type": params.get("analysis_type", "differential"),
            "fc_cutoff": params.get("fc_cutoff", 1.5),
            "p_value_cutoff": params.get("p_value_cutoff", 0.05),
            "fdr_method": params.get("fdr_method", "BH"),
            "output_dir": output_dir,
        }

        async with httpx.AsyncClient(timeout=3600) as client:
            response = await client.post(f"{self._base_url}/run_analysis", json=payload)
            response.raise_for_status()
            return response.json()

    def get_default_params(self) -> dict[str, Any]:
        return {
            "analysis_type": "differential",
            "fc_cutoff": 1.5,
            "p_value_cutoff": 0.05,
            "fdr_method": "BH",
        }

    def get_param_schema(self) -> dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "analysis_type": {
                    "type": "string",
                    "title": "Analysis type",
                    "enum": ["pca", "plsda", "differential"],
                    "default": "differential",
                },
                "fc_cutoff": {
                    "type": "number",
                    "title": "Fold change cutoff",
                    "default": 1.5,
                    "minimum": 1.0,
                },
                "p_value_cutoff": {
                    "type": "number",
                    "title": "P-value cutoff",
                    "default": 0.05,
                    "minimum": 0.001,
                    "maximum": 1.0,
                },
                "fdr_method": {
                    "type": "string",
                    "title": "FDR correction method",
                    "enum": ["BH", "bonferroni", "holm"],
                    "default": "BH",
                },
            },
        }

    async def run_stats(
        self,
        metabodata_path: str,
        output_dir: str,
        alpha: float = 0.05,
        fc_cut: float = 1.0,
    ) -> dict[str, Any]:
        """Run differential analysis on MetaboData HDF5 via /run_stats."""
        payload = {
            "metabodata_path": metabodata_path,
            "output_dir": output_dir,
            "alpha": alpha,
            "fc_cut": fc_cut,
        }
        async with httpx.AsyncClient(timeout=3600) as client:
            response = await client.post(f"{self._base_url}/run_stats", json=payload)
            response.raise_for_status()
            result = response.json()
            return result.get("data", result)

    async def health_check(self) -> bool:
        try:
            async with httpx.AsyncClient(timeout=5) as client:
                resp = await client.get(f"{self._base_url}/health")
                return resp.status_code == 200
        except httpx.HTTPError:
            return False
