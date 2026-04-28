"""Orchestrator agent FastAPI application."""

import logging
import os
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager
from uuid import uuid4

from fastapi import Depends, FastAPI, HTTPException, Request, status
from shared.app import create_app
from shared.models import AgentType, TaskRequest, TaskResponse, TaskStatus

from orchestrator.graph import build_graph
from orchestrator.llm import create_llm_from_env

logger = logging.getLogger(__name__)


@asynccontextmanager
async def orchestrator_lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    delegation_counter = getattr(app.state, "delegation_counter", None)

    llm = create_llm_from_env()
    if llm is None:
        app.state.graph = None
        logger.warning(
            "Orchestrator graph not initialized: Azure OpenAI env vars are missing"
        )
    else:
        app.state.graph = build_graph(
            llm,
            delegation_counter=delegation_counter,
        )

    yield


def register_task_routes(app: FastAPI) -> None:
    """Register the /tasks endpoint on ``app``, honoring ``app.state.auth_dependency``."""
    auth_deps = (
        [Depends(app.state.auth_dependency)] if app.state.auth_dependency else []
    )

    @app.post("/tasks", response_model=TaskResponse, dependencies=auth_deps)
    async def submit_task(request: Request, payload: TaskRequest) -> TaskResponse:
        graph = request.app.state.graph
        if graph is None:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Orchestrator graph not initialized",
            )

        task_id = str(uuid4())
        result = await graph.ainvoke(
            {
                "task": payload.task,
                "task_id": task_id,
                "context": payload.context,
            }
        )
        return TaskResponse(
            task_id=task_id,
            status=TaskStatus.COMPLETED,
            result=result.get("final_response"),
            agent=AgentType.ORCHESTRATOR,
        )


app = create_app(
    agent_type=AgentType.ORCHESTRATOR,
    lifespan=orchestrator_lifespan,
    api_key=os.getenv("ORCHESTRATOR_API_KEY"),
    require_api_key=os.getenv("ORCHESTRATOR_REQUIRE_AUTH", "true").lower() != "false",
)
register_task_routes(app)
