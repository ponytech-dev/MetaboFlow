"""Engine registry — central lookup for all available engine adapters."""

from __future__ import annotations

from app.engine.base import EngineAdapter
from app.engine.xcms_adapter import XCMSAdapter
from app.engine.stats_adapter import StatsAdapter


class EngineRegistry:
    """Singleton registry of engine adapters."""

    def __init__(self) -> None:
        self._engines: dict[str, EngineAdapter] = {}
        self._register_defaults()

    def _register_defaults(self) -> None:
        self.register(XCMSAdapter())
        self.register(StatsAdapter())

    def register(self, adapter: EngineAdapter) -> None:
        self._engines[adapter.engine_name] = adapter

    def get(self, name: str) -> EngineAdapter | None:
        return self._engines.get(name)

    def list_engines(self) -> list[dict[str, str]]:
        return [
            {"name": e.engine_name, "version": e.engine_version}
            for e in self._engines.values()
        ]

    async def health_check_all(self) -> dict[str, bool]:
        results = {}
        for name, engine in self._engines.items():
            results[name] = await engine.health_check()
        return results


# Global singleton
engine_registry = EngineRegistry()
