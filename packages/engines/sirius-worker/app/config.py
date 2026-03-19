"""Configuration for sirius-worker service."""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    sirius_bin: str = "/opt/sirius/bin/sirius"
    work_dir: str = "/tmp/sirius_jobs"
    host: str = "0.0.0.0"
    port: int = 8007
    # SIRIUS account credentials (required for CSI:FingerID)
    sirius_user: str = ""
    sirius_password: str = ""
    # Timeout for SIRIUS CLI (seconds)
    sirius_timeout: int = 300

    model_config = {"env_prefix": "SIRIUS_"}


settings = Settings()
