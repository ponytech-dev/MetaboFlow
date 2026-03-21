# Explicitly import tasks for Celery autodiscover
from app.tasks.analysis_tasks import run_analysis_pipeline  # noqa: F401
