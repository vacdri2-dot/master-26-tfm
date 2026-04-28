ARG PACKAGE
ARG AGENT_DIR
ARG MODULE

FROM python:3.12-slim AS builder
COPY --from=ghcr.io/astral-sh/uv:0.11.7 /uv /uvx /bin/

ARG PACKAGE
ARG AGENT_DIR

ENV UV_PYTHON_DOWNLOADS=0 \
    UV_LINK_MODE=copy \
    UV_NO_DEV=1

WORKDIR /app

COPY pyproject.toml uv.lock ./
COPY shared/pyproject.toml shared/pyproject.toml
COPY agents/orchestrator/pyproject.toml agents/orchestrator/pyproject.toml
COPY agents/rag/pyproject.toml agents/rag/pyproject.toml
COPY agents/code/pyproject.toml agents/code/pyproject.toml

RUN uv sync --frozen --no-install-workspace --package ${PACKAGE}

COPY shared/src shared/src
COPY agents/${AGENT_DIR}/src agents/${AGENT_DIR}/src

RUN uv sync --frozen --no-editable --package ${PACKAGE}


FROM python:3.12-slim

ARG MODULE

RUN groupadd --system app && useradd --system --gid app app

COPY --from=builder --chown=app:app /app/.venv /app/.venv

ENV PATH="/app/.venv/bin:$PATH" \
    MODULE=${MODULE}

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"]

USER app

CMD exec uvicorn ${MODULE}.app:app --host 0.0.0.0 --port 8000
