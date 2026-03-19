FROM python:3.12-slim

RUN pip install --no-cache-dir uv

WORKDIR /app

COPY pyproject.toml .
RUN uv pip install --system --no-cache -r pyproject.toml

COPY app/ app/

VOLUME ["/spectral_libraries"]

EXPOSE 8006

HEALTHCHECK --interval=15s --timeout=5s --retries=3 \
    CMD curl -f http://localhost:8006/health || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8006"]
