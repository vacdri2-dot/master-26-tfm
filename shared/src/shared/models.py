"""Pydantic models for inter-agent communication."""

from datetime import UTC, datetime
from enum import StrEnum
from typing import Any

from pydantic import BaseModel, Field


class AgentType(StrEnum):
    ORCHESTRATOR = "orchestrator"
    RAG = "rag"
    CODE = "code"


class TaskStatus(StrEnum):
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    FAILED = "failed"


class TaskRequest(BaseModel):
    task: str = Field(description="What the user wants to accomplish")
    context: dict[str, Any] | None = Field(
        default=None,
        description="Optional context: file paths, prior results, preferences",
    )


class TaskResponse(BaseModel):
    task_id: str = Field(description="Unique identifier for this task")
    status: TaskStatus
    result: str | None = None
    error: str | None = None
    agent: AgentType
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class AgentRequest(BaseModel):
    task_id: str
    agent: AgentType
    instruction: str = Field(description="The specific task for this agent")
    context: dict[str, Any] | None = None


class AgentResponse(BaseModel):
    task_id: str
    agent: AgentType
    status: TaskStatus
    output: str | None = None
    error: str | None = None


class HealthResponse(BaseModel):
    status: str = "ok"
    agent: AgentType
    version: str = "0.1.0"
