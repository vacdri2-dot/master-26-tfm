"""Test fixtures for shared library tests."""

from collections.abc import Generator

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from shared.app import create_app
from shared.models import AgentType


@pytest.fixture
def orchestrator_app() -> FastAPI:
    return create_app(agent_type=AgentType.ORCHESTRATOR)


@pytest.fixture
def orchestrator_client(orchestrator_app: FastAPI) -> Generator[TestClient, None, None]:
    with TestClient(orchestrator_app) as client:
        yield client
