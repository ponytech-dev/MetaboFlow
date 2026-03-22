"""Application configuration via environment variables."""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """MetaboFlow backend settings."""

    # App
    app_name: str = "MetaboFlow"
    debug: bool = False
    api_prefix: str = "/api/v1"
    cors_origins: list[str] = ["http://localhost:3000"]

    # Database
    database_url: str = "sqlite:///./metaboflow.db"

    # Redis / Celery
    redis_url: str = "redis://localhost:6379/0"
    celery_broker_url: str = "redis://localhost:6379/0"
    celery_result_backend: str = "redis://localhost:6379/1"

    # Auth
    secret_key: str = "metaboflow-dev-secret-change-in-production"

    # File storage
    upload_dir: str = "/data/uploads"
    results_dir: str = "/data/results"

    # Engine worker URLs
    xcms_worker_url: str = "http://localhost:8001"
    stats_worker_url: str = "http://localhost:8002"
    mzmine_worker_url: str = "http://localhost:8003"
    msdial_worker_url: str = "http://localhost:8004"
    annot_worker_url: str = "http://localhost:8006"
    sirius_worker_url: str = "http://localhost:8007"
    chart_r_worker_url: str = "http://localhost:8008"
    report_worker_url: str = "http://localhost:8009"

    model_config = {"env_prefix": "METABOFLOW_"}


settings = Settings()
