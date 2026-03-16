FROM python:3.12-slim

# System dependencies for matplotlib / freetype
RUN apt-get update && apt-get install -y --no-install-recommends \
    libfreetype6-dev \
    libpng-dev \
    pkg-config \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.cargo/bin:/root/.local/bin:$PATH"

WORKDIR /app

# Copy project definition first (layer-cache friendly)
COPY pyproject.toml ./

# Install dependencies using uv (no editable install — production image)
RUN uv pip install --system --no-cache \
    fastapi \
    "uvicorn[standard]" \
    pydantic-settings \
    matplotlib \
    seaborn \
    numpy \
    pandas \
    scikit-learn \
    scipy

# Copy source
COPY chart_service/ ./chart_service/

# Use non-interactive Agg backend — set via env to avoid any rcParams race
ENV MPLBACKEND=Agg

EXPOSE 8005

CMD ["uvicorn", "chart_service.main:app", "--host", "0.0.0.0", "--port", "8005"]
