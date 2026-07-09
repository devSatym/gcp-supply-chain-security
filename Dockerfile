# ----------------------------------------------------------------
# Stage 1 -- builder
# Install dependencies into a virtual environment so only the
# venv directory needs to be copied into the final image.
# ----------------------------------------------------------------
FROM python:3.14-slim-bookworm AS builder

WORKDIR /build

# Install build tools needed for some Python packages.
# Version pinning intentionally omitted: gcc is only used at build time in
# this stage and is discarded from the final image. Pinning would require
# manual bumps on every Debian security update with no runtime benefit.
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc \
    && rm -rf /var/lib/apt/lists/*

COPY app/requirements.txt .

RUN python -m venv /opt/venv \
    && /opt/venv/bin/pip install --upgrade pip --no-cache-dir \
    && /opt/venv/bin/pip install --no-cache-dir -r requirements.txt


# ----------------------------------------------------------------
# Stage 2 -- final image
# Runtime image containing only the virtual environment,
# application code, and a non-root user.
# ----------------------------------------------------------------
FROM python:3.14-slim-bookworm AS final

# Build-time args injected by GitHub Actions
ARG GIT_SHA=unknown

# Runtime environment
ENV GIT_SHA=${GIT_SHA} \
    PATH="/opt/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

LABEL org.opencontainers.image.source="https://github.com/musaumakau/supply-chain-security"
LABEL org.opencontainers.image.description="Supply chain security demo -- FastAPI app signed via Cosign keyless"
LABEL org.opencontainers.image.revision="${GIT_SHA}"

WORKDIR /app

# Copy only the virtual environment from the builder
COPY --from=builder /opt/venv /opt/venv

# Copy application source
COPY app/ .

# Create a dedicated non-root user with a fixed UID/GID.
# Using numeric IDs allows Kubernetes to verify runAsNonRoot.
RUN groupadd --gid 10001 appgroup \
    && useradd \
        --uid 10001 \
        --gid appgroup \
        --create-home \
        --home-dir /home/appuser \
        --shell /usr/sbin/nologin \
        appuser \
    && chown -R 10001:10001 /app

# Run as the numeric non-root user
USER 10001:10001

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]