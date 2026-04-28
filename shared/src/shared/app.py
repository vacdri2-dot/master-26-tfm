"""Base FastAPI application factory for TFM agents."""

from typing import Any

from fastapi import FastAPI

from shared.auth import build_api_key_dependency
from shared.models import AgentType, HealthResponse
from shared.telemetry import configure_telemetry, instrument_fastapi_app


class MissingApiKeyError(RuntimeError):
    """Raised when an agent declares ``require_api_key=True`` without supplying one."""


def create_app(
    agent_type: AgentType,
    api_key: str | None = None,
    require_api_key: bool = False,
    **fastapi_kwargs: Any,
) -> FastAPI:
    """Create a FastAPI application with health check, telemetry, and optional auth.

    When ``api_key`` is provided, a FastAPI dependency that enforces
    ``Authorization: Bearer <api_key>`` is stored on ``app.state.auth_dependency``
    for routers to attach to protected routes. The ``/health`` endpoint is always public.

    When ``require_api_key`` is ``True`` and ``api_key`` is missing, the factory raises
    ``MissingApiKeyError`` so an externally-exposed agent never starts unprotected.
    """
    if require_api_key and not api_key:
        raise MissingApiKeyError(
            f"{agent_type.value} agent requires api_key but none was provided"
        )

    delegation_counter = configure_telemetry(service_name=agent_type.value)

    fastapi_kwargs.setdefault("title", f"TFM — {agent_type.value} agent")
    fastapi_kwargs.setdefault("version", "0.1.0")

    app = FastAPI(**fastapi_kwargs)
    instrument_fastapi_app(app)
    app.state.delegation_counter = delegation_counter
    app.state.auth_dependency = build_api_key_dependency(api_key) if api_key else None

    @app.get("/health", response_model=HealthResponse)
    async def health() -> HealthResponse:
        return HealthResponse(agent=agent_type)

    return app
