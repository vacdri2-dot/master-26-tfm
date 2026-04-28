"""Tests for the shared API key authentication dependency."""

from collections.abc import Generator

import pytest
from fastapi import Depends, FastAPI
from fastapi.testclient import TestClient
from shared.app import MissingApiKeyError, create_app
from shared.auth import build_api_key_dependency
from shared.models import AgentType

TEST_API_KEY = "test-key-0123456789abcdef"  # pragma: allowlist secret


@pytest.fixture
def protected_app() -> FastAPI:
    app = create_app(agent_type=AgentType.ORCHESTRATOR, api_key=TEST_API_KEY)

    @app.get("/protected", dependencies=[Depends(app.state.auth_dependency)])
    async def protected() -> dict[str, str]:
        return {"ok": "true"}

    return app


@pytest.fixture
def protected_client(protected_app: FastAPI) -> Generator[TestClient, None, None]:
    with TestClient(protected_app) as client:
        yield client


class TestCreateAppAuth:
    def test_auth_dependency_is_none_without_api_key(self):
        app = create_app(agent_type=AgentType.ORCHESTRATOR)
        assert app.state.auth_dependency is None

    def test_auth_dependency_is_set_with_api_key(self, protected_app: FastAPI):
        assert protected_app.state.auth_dependency is not None


class TestHealthAlwaysPublic:
    def test_health_returns_200_without_auth_when_key_configured(
        self, protected_client: TestClient
    ):
        response = protected_client.get("/health")
        assert response.status_code == 200


class TestProtectedEndpoints:
    def test_401_without_auth_header(self, protected_client: TestClient):
        response = protected_client.get("/protected")
        assert response.status_code == 401

    def test_401_with_wrong_scheme(self, protected_client: TestClient):
        response = protected_client.get(
            "/protected",
            headers={"Authorization": f"Basic {TEST_API_KEY}"},
        )
        assert response.status_code == 401

    def test_401_with_invalid_token(self, protected_client: TestClient):
        response = protected_client.get(
            "/protected",
            headers={"Authorization": "Bearer wrong-token"},
        )
        assert response.status_code == 401

    def test_401_response_includes_www_authenticate(self, protected_client: TestClient):
        response = protected_client.get("/protected")
        assert response.headers.get("www-authenticate") == "Bearer"

    def test_200_with_valid_token(self, protected_client: TestClient):
        response = protected_client.get(
            "/protected",
            headers={"Authorization": f"Bearer {TEST_API_KEY}"},
        )
        assert response.status_code == 200
        assert response.json() == {"ok": "true"}


class TestBuildApiKeyDependency:
    def test_empty_key_raises_value_error(self):
        with pytest.raises(ValueError, match="non-empty"):
            build_api_key_dependency("")


class TestRequireApiKeyGuard:
    def test_raises_when_required_and_missing(self):
        with pytest.raises(MissingApiKeyError, match="requires api_key"):
            create_app(agent_type=AgentType.ORCHESTRATOR, require_api_key=True)

    def test_raises_when_required_and_empty_string(self):
        with pytest.raises(MissingApiKeyError):
            create_app(
                agent_type=AgentType.ORCHESTRATOR,
                api_key="",
                require_api_key=True,
            )

    def test_succeeds_when_required_and_provided(self):
        app = create_app(
            agent_type=AgentType.ORCHESTRATOR,
            api_key=TEST_API_KEY,
            require_api_key=True,
        )
        assert app.state.auth_dependency is not None

    def test_no_op_when_not_required(self):
        app = create_app(agent_type=AgentType.ORCHESTRATOR, require_api_key=False)
        assert app.state.auth_dependency is None
