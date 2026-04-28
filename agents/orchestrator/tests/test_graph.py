"""Unit tests for the orchestrator LangGraph graph with mocked LLM."""

import uuid

import pytest
from orchestrator.graph import build_graph
from shared.models import TaskStatus

from tests.conftest import make_llm


@pytest.mark.asyncio
async def test_route_to_rag() -> None:
    llm = make_llm(
        classifications=[{"agent": "rag", "reasoning": "needs document search"}],
        responses=["Here is the answer based on the documents."],
    )
    graph = build_graph(llm)
    result = await graph.ainvoke(
        {
            "task": "What does the architecture document say about networking?",
            "task_id": str(uuid.uuid4()),
        }
    )
    assert result["classification"]["agent"] == "rag"
    assert len(result["agent_responses"]) == 1
    assert result["agent_responses"][0].agent == "rag"
    assert result["agent_responses"][0].status == TaskStatus.FAILED
    assert result["final_response"]


@pytest.mark.asyncio
async def test_route_to_code() -> None:
    llm = make_llm(
        classifications=[{"agent": "code", "reasoning": "needs code execution"}],
        responses=["Here is the code result."],
    )
    graph = build_graph(llm)
    result = await graph.ainvoke(
        {
            "task": "Write a Python function that calculates fibonacci",
            "task_id": str(uuid.uuid4()),
        }
    )
    assert result["classification"]["agent"] == "code"
    assert len(result["agent_responses"]) == 1
    assert result["agent_responses"][0].agent == "code"
    assert result["agent_responses"][0].status == TaskStatus.FAILED
    assert result["final_response"]


@pytest.mark.asyncio
async def test_route_direct() -> None:
    llm = make_llm(
        classifications=[{"agent": "direct", "reasoning": "simple question"}],
        responses=["The answer is 42."],
    )
    graph = build_graph(llm)
    result = await graph.ainvoke(
        {
            "task": "What is 6 times 7?",
            "task_id": str(uuid.uuid4()),
        }
    )
    assert result["classification"]["agent"] == "direct"
    assert result.get("agent_responses", []) == []
    assert result["final_response"] == "The answer is 42."


@pytest.mark.asyncio
async def test_invalid_llm_classification_falls_back_to_direct() -> None:
    llm = make_llm(
        classifications=[ValueError("invalid structured output")],
        responses=["Fallback answer."],
    )
    graph = build_graph(llm)
    result = await graph.ainvoke(
        {
            "task": "Some ambiguous task",
            "task_id": str(uuid.uuid4()),
        }
    )
    assert result["classification"]["agent"] == "direct"
    assert result["final_response"] == "Fallback answer."
