"""Tests for the OpenTelemetry setup module."""

import logging

import pytest
from opentelemetry import metrics, trace
from opentelemetry.metrics import Counter
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from shared.telemetry import configure_telemetry

from shared import telemetry


@pytest.fixture(autouse=True)
def reset_configured_state(monkeypatch):
    monkeypatch.setattr(telemetry, "_configured_service_name", None)


class TestConfigureTelemetry:
    def test_returns_counter(self, monkeypatch):
        monkeypatch.delenv("APPLICATIONINSIGHTS_CONNECTION_STRING", raising=False)
        counter = configure_telemetry("orchestrator")
        assert isinstance(counter, Counter)

    def test_uses_azure_monitor_when_connection_string_set(self, monkeypatch):
        monkeypatch.setenv(
            "APPLICATIONINSIGHTS_CONNECTION_STRING", "InstrumentationKey=fake"
        )
        calls: list[dict[str, object]] = []

        def fake_configure(**kwargs):
            calls.append(kwargs)

        monkeypatch.setattr(telemetry, "configure_azure_monitor", fake_configure)

        configure_telemetry("orchestrator")

        assert len(calls) == 1
        assert calls[0]["connection_string"] == "InstrumentationKey=fake"
        assert calls[0]["instrumentation_options"] == {"fastapi": {"enabled": False}}
        resource = calls[0]["resource"]
        assert isinstance(resource, Resource)
        assert resource.attributes["service.name"] == "orchestrator"
        assert resource.attributes["service.version"] == "0.1.0"

    def test_skips_azure_monitor_without_connection_string(self, monkeypatch):
        monkeypatch.delenv("APPLICATIONINSIGHTS_CONNECTION_STRING", raising=False)
        called = False

        def fake_configure(**_kwargs):
            nonlocal called
            called = True

        monkeypatch.setattr(telemetry, "configure_azure_monitor", fake_configure)

        configure_telemetry("orchestrator")

        assert called is False

    def test_fallback_sets_global_sdk_providers(self, monkeypatch):
        monkeypatch.delenv("APPLICATIONINSIGHTS_CONNECTION_STRING", raising=False)

        configure_telemetry("orchestrator")

        assert isinstance(trace.get_tracer_provider(), TracerProvider)
        assert isinstance(metrics.get_meter_provider(), MeterProvider)

    def test_same_service_name_is_idempotent(self, monkeypatch):
        monkeypatch.setenv(
            "APPLICATIONINSIGHTS_CONNECTION_STRING", "InstrumentationKey=fake"
        )
        calls = 0

        def fake_configure(**_kwargs):
            nonlocal calls
            calls += 1

        monkeypatch.setattr(telemetry, "configure_azure_monitor", fake_configure)

        configure_telemetry("orchestrator")
        configure_telemetry("orchestrator")
        configure_telemetry("orchestrator")

        assert calls == 1

    def test_different_service_name_logs_warning(self, monkeypatch, caplog):
        monkeypatch.delenv("APPLICATIONINSIGHTS_CONNECTION_STRING", raising=False)

        configure_telemetry("orchestrator")

        with caplog.at_level(logging.WARNING, logger="shared.telemetry"):
            configure_telemetry("rag")

        assert "already configured for service 'orchestrator'" in caplog.text
        assert "'rag'" in caplog.text
