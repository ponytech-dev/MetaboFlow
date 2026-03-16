"""Chart service configuration via environment variables."""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Chart service settings."""

    # Output
    output_dir: str = "./data/charts"
    dpi: int = 300
    default_format: str = "png"

    # Service
    host: str = "0.0.0.0"
    port: int = 8005
    debug: bool = False

    model_config = {"env_prefix": "CHART_"}


settings = Settings()
