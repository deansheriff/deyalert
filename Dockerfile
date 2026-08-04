# syntax=docker/dockerfile:1

FROM python:3.12-slim AS builder
COPY --from=ghcr.io/astral-sh/uv:0.11.17 /uv /uvx /bin/

ENV UV_PYTHON_DOWNLOADS=0
ENV UV_PROJECT_ENVIRONMENT=/opt/venv
ENV UV_NO_CACHE=1

WORKDIR /build
COPY backend/pyproject.toml ./
COPY backend/uv.lock ./
COPY backend/app ./app
RUN uv sync --locked --no-dev --no-editable

FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PORT=8000
ENV PATH="/opt/venv/bin:${PATH}"

RUN useradd --create-home --uid 10001 appuser

WORKDIR /app
COPY --from=builder /opt/venv /opt/venv
COPY --chown=appuser:appuser backend/app ./app
COPY --chown=appuser:appuser backend/migrations ./migrations
COPY --chown=appuser:appuser backend/scripts ./scripts

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD ["python", "-c", "import os, urllib.request; urllib.request.urlopen(f\"http://127.0.0.1:{os.environ.get('PORT', '8000')}/ready\", timeout=3)"]

CMD ["sh", "scripts/start.sh"]
