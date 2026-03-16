"""EngineAdapter abstract base class.

All engine adapters must implement this interface. Each adapter wraps
a specific analysis engine (XCMS, MZmine, limma, matchms, etc.) running
in its own Docker container.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any


class ValidationResult:
    """Result of parameter validation."""

    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []

    @property
    def is_valid(self) -> bool:
        return len(self.errors) == 0

    def add_error(self, msg: str) -> None:
        self.errors.append(msg)

    def add_warning(self, msg: str) -> None:
        self.warnings.append(msg)


class EngineAdapter(ABC):
    """Abstract base class for all engine adapters.

    Each adapter wraps a Docker-containerized analysis engine,
    translating MetaboFlow API calls into engine-specific operations.
    """

    @property
    @abstractmethod
    def engine_name(self) -> str:
        """Unique engine identifier, e.g. 'xcms', 'mzmine', 'limma'."""
        ...

    @property
    @abstractmethod
    def engine_version(self) -> str:
        """Runtime-detected engine version string."""
        ...

    @abstractmethod
    def validate_params(self, params: dict[str, Any]) -> ValidationResult:
        """Validate parameters before execution.

        Returns a ValidationResult with any errors/warnings.
        """
        ...

    @abstractmethod
    async def run(self, input_path: str, params: dict[str, Any], output_dir: str) -> dict[str, Any]:
        """Execute the engine on input data.

        Args:
            input_path: Path to input .metabodata file or data directory.
            params: Engine-specific parameters.
            output_dir: Directory for output files.

        Returns:
            Dict with result metadata (output file paths, stats, etc.)
        """
        ...

    @abstractmethod
    def get_default_params(self) -> dict[str, Any]:
        """Return recommended default parameters for this engine."""
        ...

    @abstractmethod
    def get_param_schema(self) -> dict[str, Any]:
        """Return JSON Schema for the parameter set.

        Used by the frontend to dynamically render parameter forms.
        """
        ...

    async def health_check(self) -> bool:
        """Check if the engine container is reachable."""
        return True
