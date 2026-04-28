"""Tests for the base FastAPI application factory."""

from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.testclient import TestClient
from opentelemetry.metrics import Counter
from shared.app import create_app
from shared.models import AgentType


class TestHealthEndpoint:
    def test_health_returns_200(self, orchestrator_client: TestClient):
        response = orchestrator_client.get("/health")
        assert response.status_code == 200

    def test_health_returns_agent_type(self, orchestrator_client: TestClient):
        data = orchestrator_client.get("/health").json()
        assert data["agent"] == "orchestrator"

    def test_health_returns_status_ok(self, orchestrator_client: TestClient):
        data = orchestrator_client.get("/health").json()
        assert data["status"] == "ok"

    def test_health_returns_version(self, orchestrator_client: TestClient):
        data = orchestrator_client.get("/health").json()
        assert data["version"] == "0.1.0"

    def test_health_schema(self, orchestrator_client: TestClient):
        data = orchestrator_client.get("/health").json()
        assert set(data.keys()) == {"status", "agent", "version"}


class TestCreateApp:
    def test_creates_app_for_each_agent_type(self):
        for agent_type in AgentType:
            app = create_app(agent_type=agent_type)
            with TestClient(app) as client:
                response = client.get("/health")
                assert response.status_code == 200
                assert response.json()["agent"] == agent_type.value

    def test_app_title_includes_agent_name(self):
        app = create_app(agent_type=AgentType.RAG)
        assert "rag" in app.title.lower()

    def test_custom_kwargs_forwarded(self):
        app = create_app(
            agent_type=AgentType.CODE,
            description="Custom description",
        )
        assert app.description == "Custom description"

    def test_openapi_schema_available(self, orchestrator_client: TestClient):
        response = orchestrator_client.get("/openapi.json")
        assert response.status_code == 200
        schema = response.json()
        assert "/health" in schema["paths"]

    def test_custom_lifespan_is_preserved(self):
        calls: list[str] = []

        @asynccontextmanager
        async def custom_lifespan(_: FastAPI) -> AsyncGenerator[None, None]:
            calls.append("startup")
            yield
            calls.append("shutdown")

        app = create_app(
            agent_type=AgentType.CODE,
            lifespan=custom_lifespan,
        )

        with TestClient(app):
            assert calls == ["startup"]

        assert calls == ["startup", "shutdown"]

    def test_exposes_delegation_counter_on_state(self):
        app = create_app(agent_type=AgentType.ORCHESTRATOR)
        assert isinstance(app.state.delegation_counter, Counter)

    def test_instruments_fastapi_app(self, monkeypatch):
        calls: list[FastAPI] = []

        def fake_instrument(app: FastAPI) -> None:
            calls.append(app)

        monkeypatch.setattr("shared.app.instrument_fastapi_app", fake_instrument)

        app = create_app(agent_type=AgentType.ORCHESTRATOR)

        assert calls == [app]
