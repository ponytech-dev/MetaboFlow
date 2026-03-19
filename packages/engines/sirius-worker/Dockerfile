# SIRIUS requires Java 21+ and ~2GB disk space
FROM eclipse-temurin:21-jre-noble

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl python3 python3-pip python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Download and install SIRIUS CLI
# NOTE: Update this URL when new SIRIUS versions are released
# Check https://github.com/sirius-ms/sirius/releases for latest
ARG SIRIUS_VERSION=6.1.1
RUN curl -L -o /tmp/sirius.zip \
    "https://github.com/sirius-ms/sirius/releases/download/v${SIRIUS_VERSION}/sirius-${SIRIUS_VERSION}-linux-x64.zip" \
    && mkdir -p /opt/sirius \
    && cd /opt && unzip /tmp/sirius.zip \
    && mv sirius-* sirius || true \
    && rm /tmp/sirius.zip \
    && chmod +x /opt/sirius/bin/sirius 2>/dev/null || true

# Install Python dependencies
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /app
COPY pyproject.toml .
RUN pip install --no-cache-dir uv && uv pip install --no-cache -r pyproject.toml

COPY app/ app/

# Working directory for SIRIUS jobs
RUN mkdir -p /tmp/sirius_jobs

EXPOSE 8007

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:8007/health || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8007"]
