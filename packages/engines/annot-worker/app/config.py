"""Configuration for annot-worker service."""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    library_dir: str = "/spectral_libraries"
    library_subdir: str = "deduplicated"  # use deduplicated/ by default (has Sources + Quality_score)
    registry_db: str = "/spectral_libraries/registry.db"
    host: str = "0.0.0.0"
    port: int = 8006
    max_cache_libraries: int = 10

    @property
    def library_base_path(self) -> str:
        """Resolve library base path (deduplicated/ preferred, fallback to converted/)."""
        import os
        dedup_path = os.path.join(self.library_dir, self.library_subdir)
        if os.path.isdir(dedup_path):
            return dedup_path
        return os.path.join(self.library_dir, "converted")

    model_config = {"env_prefix": "ANNOTWORKER_"}


settings = Settings()
