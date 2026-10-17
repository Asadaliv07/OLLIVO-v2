# Production Dockerfile for Ollivo AirLLM Local Inference Service
# Supports CPU, Apple Silicon, and NVIDIA CUDA deployments

FROM python:3.11-slim

# Prevent interactive prompts and unbuffer Python stdout/stderr
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Install system utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Python requirements
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install -r requirements.txt

# Copy service source code
COPY . /app/airllm_service/

# Create non-root system user and storage cache directories
RUN useradd -m -u 1000 ollivo && \
    mkdir -p /home/ollivo/.cache/ollivo/airllm/hub \
             /home/ollivo/.cache/ollivo/airllm/shards && \
    chown -R ollivo:ollivo /app /home/ollivo/.cache

USER ollivo

ENV AIRLLM_HOST=0.0.0.0 \
    AIRLLM_PORT=8765 \
    AIRLLM_CACHE_DIR=/home/ollivo/.cache/ollivo/airllm/hub \
    AIRLLM_SHARDS_DIR=/home/ollivo/.cache/ollivo/airllm/shards

EXPOSE 8765

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -f http://127.0.0.1:8765/health || exit 1

ENTRYPOINT ["python", "-m", "airllm_service.service"]
