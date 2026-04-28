"""LangGraph state definition for the orchestrator graph."""

from typing import Literal, NotRequired, TypedDict

from shared.models import AgentResponse


class TaskClassification(TypedDict):
    agent: Literal["rag", "code", "direct"]
    reasoning: str


class OrchestratorState(TypedDict):
    task: str
    task_id: str
    context: NotRequired[dict | None]
    classification: NotRequired[TaskClassification]
    agent_responses: NotRequired[list[AgentResponse]]
    final_response: NotRequired[str]
    error: NotRequired[str | None]
