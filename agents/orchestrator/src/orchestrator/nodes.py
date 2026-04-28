"""LangGraph node functions for the orchestrator graph."""

import logging
from typing import Literal

from langchain_core.language_models import BaseChatModel
from langchain_core.messages import HumanMessage, SystemMessage
from opentelemetry import trace
from opentelemetry.metrics import Counter
from opentelemetry.trace import Status, StatusCode
from pydantic import BaseModel
from shared.models import AgentResponse, AgentType, TaskStatus

from orchestrator.state import OrchestratorState, TaskClassification

logger = logging.getLogger(__name__)
tracer = trace.get_tracer(__name__)


class ClassificationResult(BaseModel):
    agent: Literal["rag", "code", "direct"]
    reasoning: str


CLASSIFY_SYSTEM_PROMPT = """\
You are a task classifier. Given a user task, decide which agent should handle it.

Available agents:
- "rag": For questions that require searching documents, knowledge bases, or retrieving information.
- "code": For tasks that require writing, executing, or analyzing code.
- "direct": For simple questions you can answer directly without any agent.
"""

COMPOSE_SYSTEM_PROMPT = """\
You are a helpful assistant composing a final response for the user.
Use the agent results below to craft a clear, complete answer.
If an agent failed, acknowledge the issue and provide what you can.
"""


def make_classify_node(llm: BaseChatModel):
    structured_llm = llm.with_structured_output(ClassificationResult)

    async def classify(state: OrchestratorState) -> dict:
        with tracer.start_as_current_span("orchestrator.classify") as span:
            span.set_attribute("task.id", state["task_id"])
            try:
                result = await structured_llm.ainvoke(
                    [
                        SystemMessage(content=CLASSIFY_SYSTEM_PROMPT),
                        HumanMessage(content=state["task"]),
                    ]
                )
                validated = ClassificationResult.model_validate(result)
                classification: TaskClassification = {
                    "agent": validated.agent,
                    "reasoning": validated.reasoning,
                }
                span.set_attribute("classification.agent", validated.agent)
            except Exception as exc:
                classification = TaskClassification(
                    agent="direct", reasoning="fallback"
                )
                span.set_attribute("classification.agent", "direct")
                span.set_attribute("classification.fallback", True)
                span.set_attribute("error.type", type(exc).__name__)
                span.record_exception(exc)
                span.set_status(Status(StatusCode.ERROR, str(exc)))
                logger.exception(
                    "Structured classification failed, falling back to direct"
                )
        return {"classification": classification}

    return classify


def make_call_rag_node(delegation_counter: Counter | None = None):
    async def call_rag(state: OrchestratorState) -> dict:
        with tracer.start_as_current_span("orchestrator.delegate.rag") as span:
            span.set_attribute("task.id", state["task_id"])
            span.set_attribute("agent.target", AgentType.RAG.value)
            if delegation_counter is not None:
                delegation_counter.add(
                    1, attributes={"target_agent": AgentType.RAG.value}
                )
            response = AgentResponse(
                task_id=state["task_id"],
                agent=AgentType.RAG,
                status=TaskStatus.FAILED,
                error="RAG agent integration pending",
            )
        return {"agent_responses": [*state.get("agent_responses", []), response]}

    return call_rag


def make_call_code_node(delegation_counter: Counter | None = None):
    async def call_code(state: OrchestratorState) -> dict:
        with tracer.start_as_current_span("orchestrator.delegate.code") as span:
            span.set_attribute("task.id", state["task_id"])
            span.set_attribute("agent.target", AgentType.CODE.value)
            if delegation_counter is not None:
                delegation_counter.add(
                    1, attributes={"target_agent": AgentType.CODE.value}
                )
            response = AgentResponse(
                task_id=state["task_id"],
                agent=AgentType.CODE,
                status=TaskStatus.FAILED,
                error="Code agent integration pending",
            )
        return {"agent_responses": [*state.get("agent_responses", []), response]}

    return call_code


def make_compose_node(llm: BaseChatModel):
    async def compose_response(state: OrchestratorState) -> dict:
        with tracer.start_as_current_span("orchestrator.compose_response") as span:
            span.set_attribute("task.id", state["task_id"])
            # classify node always runs before compose, so classification exists
            classification = state["classification"]  # type: ignore[reportTypedDictNotRequiredAccess]

            if classification["agent"] == "direct":
                response = await llm.ainvoke(
                    [
                        HumanMessage(content=state["task"]),
                    ]
                )
                return {"final_response": response.content}

            agent_results = "\n\n".join(
                f"[{r.agent.value}]: {r.output or r.error or 'no output'}"
                for r in state.get("agent_responses", [])
            )
            span.set_attribute(
                "agent_responses.count", len(state.get("agent_responses", []))
            )
            response = await llm.ainvoke(
                [
                    SystemMessage(content=COMPOSE_SYSTEM_PROMPT),
                    HumanMessage(
                        content=f"Original task: {state['task']}\n\nAgent results:\n{agent_results}"
                    ),
                ]
            )
            return {"final_response": response.content}

    return compose_response


def route_by_classification(state: OrchestratorState) -> str:
    # classify node always runs before routing, so classification exists
    return state["classification"]["agent"]  # type: ignore[reportTypedDictNotRequiredAccess]
