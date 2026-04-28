"""LangGraph graph definition and compilation for the orchestrator."""

from langchain_core.language_models import BaseChatModel
from langgraph.graph import END, StateGraph
from langgraph.graph.state import CompiledStateGraph
from opentelemetry.metrics import Counter

from orchestrator.nodes import (
    make_call_code_node,
    make_call_rag_node,
    make_classify_node,
    make_compose_node,
    route_by_classification,
)
from orchestrator.state import OrchestratorState


def build_graph(
    llm: BaseChatModel,
    delegation_counter: Counter | None = None,
) -> CompiledStateGraph:
    graph = StateGraph(OrchestratorState)

    graph.add_node("classify", make_classify_node(llm))
    graph.add_node("call_rag", make_call_rag_node(delegation_counter))
    graph.add_node("call_code", make_call_code_node(delegation_counter))
    graph.add_node("compose_response", make_compose_node(llm))

    graph.set_entry_point("classify")

    graph.add_conditional_edges(
        source="classify",
        path=route_by_classification,
        path_map={
            "rag": "call_rag",
            "code": "call_code",
            "direct": "compose_response",
        },
    )

    graph.add_edge("call_rag", "compose_response")
    graph.add_edge("call_code", "compose_response")
    graph.add_edge("compose_response", END)

    return graph.compile()
