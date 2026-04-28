"""Shared test fixtures and fake LLM helpers for the orchestrator test suite."""

import os
from typing import Any, cast

from langchain_core.language_models import BaseChatModel
from langchain_core.messages import AIMessage

os.environ.setdefault("ORCHESTRATOR_REQUIRE_AUTH", "false")


class FakeStructuredLLM:
    def __init__(self, responses: list[object]) -> None:
        self._responses = responses

    async def ainvoke(self, _messages: list[object]) -> object:
        response = self._responses.pop(0)
        if isinstance(response, Exception):
            raise response
        return response


class FakeLLM:
    def __init__(self, classifications: list[Any], responses: list[str]) -> None:
        self._classifications = classifications
        self._responses = responses

    def with_structured_output(self, schema: Any) -> FakeStructuredLLM:
        structured_responses: list[object] = []
        for item in self._classifications:
            if isinstance(item, Exception):
                structured_responses.append(item)
            else:
                structured_responses.append(schema.model_validate(item))
        return FakeStructuredLLM(structured_responses)

    async def ainvoke(self, _messages: list[object]) -> AIMessage:
        return AIMessage(content=self._responses.pop(0))


def make_llm(classifications: list[Any], responses: list[str]) -> BaseChatModel:
    return cast(
        BaseChatModel, FakeLLM(classifications=classifications, responses=responses)
    )
