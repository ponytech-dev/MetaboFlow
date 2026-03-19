"""Configuration for annot-worker service."""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    library_dir: str = "/spectral_libraries"
    registry_db: str = "/spectral_libraries/registry.db"
    host: str = "0.0.0.0"
    port: int = 8006
    max_cache_libraries: int = 10

    model_config = {"env_prefix": "ANNOTWORKER_"}


settings = Settings()
