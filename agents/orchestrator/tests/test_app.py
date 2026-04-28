"""Tests for the orchestrator HTTP endpoints."""

import importlib
from collections.abc import Generator

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from orchestrator.app import register_task_routes
from orchestrator.graph import build_graph
from shared.app import MissingApiKeyError, create_app
from shared.models import AgentType

from tests.conftest import make_llm

ORCHESTRATOR_TEST_KEY = "test-key-0123456789abcdef"  # pragma: allowlist secret


class TestTasksRouting:
    def test_direct_route(self, monkeypatch: pytest.MonkeyPatch):
        fake_llm = make_llm(
            classifications=[{"agent": "direct", "reasoning": "simple"}],
            responses=["Direct response"],
        )
        monkeypatch.setattr("orchestrator.app.create_llm_from_env", lambda: fake_llm)
        from orchestrator.app import app

        with TestClient(app) as client:
            response = client.post("/tasks", json={"task": "What is 2+2?"})

        assert response.status_code == 200
        body = response.json()
        assert body["status"] == "completed"
        assert body["agent"] == "orchestrator"
        assert body["result"] == "Direct response"
        assert body["task_id"]

    def test_rag_route(self, monkeypatch: pytest.MonkeyPatch):
        fake_llm = make_llm(
            classifications=[{"agent": "rag", "reasoning": "needs docs"}],
            responses=["Synthesized from RAG"],
        )
        monkeypatch.setattr("orchestrator.app.create_llm_from_env", lambda: fake_llm)
        from orchestrator.app import app

        with TestClient(app) as client:
            response = client.post(
                "/tasks", json={"task": "What does the architecture doc say?"}
            )

        assert response.status_code == 200
        assert response.json()["result"] == "Synthesized from RAG"

    def test_code_route(self, monkeypatch: pytest.MonkeyPatch):
        fake_llm = make_llm(
            classifications=[{"agent": "code", "reasoning": "needs code"}],
            responses=["Synthesized from code"],
        )
        monkeypatch.setattr("orchestrator.app.create_llm_from_env", lambda: fake_llm)
        from orchestrator.app import app

        with TestClient(app) as client:
            response = client.post("/tasks", json={"task": "Compute fibonacci"})

        assert response.status_code == 200


class TestTasksGraphNotInitialized:
    def test_503_when_env_vars_missing(self, monkeypatch: pytest.MonkeyPatch):
        monkeypatch.setattr("orchestrator.app.create_llm_from_env", lambda: None)
        from orchestrator.app import app

        with TestClient(app) as client:
            response = client.post("/tasks", json={"task": "anything"})

        assert response.status_code == 503


class TestTasksValidation:
    def test_422_when_task_field_missing(self, monkeypatch: pytest.MonkeyPatch):
        fake_llm = make_llm(classifications=[], responses=[])
        monkeypatch.setattr("orchestrator.app.create_llm_from_env", lambda: fake_llm)
        from orchestrator.app import app

        with TestClient(app) as client:
            response = client.post("/tasks", json={})

        assert response.status_code == 422


@pytest.fixture
def authenticated_app() -> FastAPI:
    fake_llm = make_llm(
        classifications=[{"agent": "direct", "reasoning": "simple"}],
        responses=["Authenticated response"],
    )
    app = create_app(
        agent_type=AgentType.ORCHESTRATOR,
        api_key=ORCHESTRATOR_TEST_KEY,
    )
    app.state.graph = build_graph(fake_llm)
    register_task_routes(app)
    return app


@pytest.fixture
def authenticated_client(
    authenticated_app: FastAPI,
) -> Generator[TestClient, None, None]:
    with TestClient(authenticated_app) as client:
        yield client


class TestTasksAuth:
    def test_401_without_bearer(self, authenticated_client: TestClient):
        response = authenticated_client.post("/tasks", json={"task": "x"})
        assert response.status_code == 401

    def test_401_with_wrong_token(self, authenticated_client: TestClient):
        response = authenticated_client.post(
            "/tasks",
            json={"task": "x"},
            headers={"Authorization": "Bearer wrong-token"},
        )
        assert response.status_code == 401

    def test_200_with_correct_token(self, authenticated_client: TestClient):
        response = authenticated_client.post(
            "/tasks",
            json={"task": "x"},
            headers={"Authorization": f"Bearer {ORCHESTRATOR_TEST_KEY}"},
        )
        assert response.status_code == 200
        assert response.json()["result"] == "Authenticated response"

    def test_health_stays_public(self, authenticated_client: TestClient):
        response = authenticated_client.get("/health")
        assert response.status_code == 200


class TestRequireAuthEnv:
    def test_module_import_fails_when_required_and_key_missing(
        self, monkeypatch: pytest.MonkeyPatch
    ):
        monkeypatch.setenv("ORCHESTRATOR_REQUIRE_AUTH", "true")
        monkeypatch.delenv("ORCHESTRATOR_API_KEY", raising=False)

        import orchestrator.app as orch_app

        with pytest.raises(MissingApiKeyError):
            importlib.reload(orch_app)

    def test_module_import_succeeds_when_required_and_key_present(
        self, monkeypatch: pytest.MonkeyPatch
    ):
        monkeypatch.setenv("ORCHESTRATOR_REQUIRE_AUTH", "true")
        monkeypatch.setenv("ORCHESTRATOR_API_KEY", ORCHESTRATOR_TEST_KEY)

        import orchestrator.app as orch_app

        importlib.reload(orch_app)
        assert orch_app.app.state.auth_dependency is not None

    def test_module_import_succeeds_when_not_required_and_key_missing(
        self, monkeypatch: pytest.MonkeyPatch
    ):
        monkeypatch.setenv("ORCHESTRATOR_REQUIRE_AUTH", "false")
        monkeypatch.delenv("ORCHESTRATOR_API_KEY", raising=False)

        import orchestrator.app as orch_app

        importlib.reload(orch_app)
        assert orch_app.app.state.auth_dependency is None

    def test_module_import_fails_by_default_when_key_missing(
        self, monkeypatch: pytest.MonkeyPatch
    ):
        monkeypatch.delenv("ORCHESTRATOR_REQUIRE_AUTH", raising=False)
        monkeypatch.delenv("ORCHESTRATOR_API_KEY", raising=False)

        import orchestrator.app as orch_app

        with pytest.raises(MissingApiKeyError):
            importlib.reload(orch_app)
