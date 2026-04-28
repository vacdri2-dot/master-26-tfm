"""OpenTelemetry setup for TFM agents."""

import logging
import os
import sys

from azure.monitor.opentelemetry import configure_azure_monitor
from fastapi import FastAPI
from opentelemetry import metrics, trace
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.metrics import Counter
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import (
    ConsoleMetricExporter,
    PeriodicExportingMetricReader,
)
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor, ConsoleSpanExporter

# Force root logger to emit to stdout so Azure Monitor SDK diagnostics surface
# in container logs while debugging telemetry issues.
logging.basicConfig(
    level=os.getenv("PYTHON_LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    stream=sys.stdout,
    force=True,
)

logger = logging.getLogger(__name__)

_DELEGATION_COUNTER_NAME = "orchestrator.delegations.count"
_DELEGATION_COUNTER_DESC = "Number of orchestrator delegations by target agent"

_configured_service_name: str | None = None


def configure_telemetry(service_name: str) -> Counter:
    """Configure OTel providers and return the delegation counter.

    Uses the Azure Monitor distro when APPLICATIONINSIGHTS_CONNECTION_STRING is
    set, otherwise falls back to console exporters for local development.
    One agent per process: only the first call configures providers; subsequent
    calls with a different service_name log a warning and reuse the original
    configuration, since OTel providers are process-global.
    """
    global _configured_service_name
    if _configured_service_name is None:
        resource = Resource.create(
            {
                "service.name": service_name,
                "service.version": "0.1.0",
            }
        )
        connection_string = os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING")
        logger.info(
            "configure_telemetry: service=%s, connection_string_present=%s, "
            "azure_client_id=%s",
            service_name,
            bool(connection_string),
            os.getenv("AZURE_CLIENT_ID", "<unset>"),
        )
        if connection_string:
            logger.info(
                "configure_telemetry: invoking configure_azure_monitor with "
                "ingestion_endpoint=%s",
                _extract_ingestion_endpoint(connection_string),
            )
            configure_azure_monitor(
                connection_string=connection_string,
                instrumentation_options={"fastapi": {"enabled": False}},
                resource=resource,
            )
            logger.info("configure_telemetry: configure_azure_monitor returned OK")
        else:
            logger.info(
                "configure_telemetry: no connection string, falling back to console"
            )
            _configure_console_fallback(resource)
        _configured_service_name = service_name
    elif _configured_service_name != service_name:
        logger.warning(
            "Telemetry already configured for service %r; ignoring reconfiguration "
            "request for service %r (OTel providers are process-global)",
            _configured_service_name,
            service_name,
        )

    meter = metrics.get_meter("shared.telemetry")
    return meter.create_counter(
        name=_DELEGATION_COUNTER_NAME,
        description=_DELEGATION_COUNTER_DESC,
        unit="1",
    )


def instrument_fastapi_app(app: FastAPI) -> None:
    FastAPIInstrumentor.instrument_app(app)
    logger.info("instrument_fastapi_app: FastAPI instance instrumented")


def _extract_ingestion_endpoint(connection_string: str) -> str:
    parts = dict(kv.split("=", 1) for kv in connection_string.split(";") if "=" in kv)
    return parts.get("IngestionEndpoint", "<missing>")


def _configure_console_fallback(resource: Resource) -> None:
    tracer_provider = TracerProvider(resource=resource)
    tracer_provider.add_span_processor(BatchSpanProcessor(ConsoleSpanExporter()))
    trace.set_tracer_provider(tracer_provider)

    meter_provider = MeterProvider(
        resource=resource,
        metric_readers=[PeriodicExportingMetricReader(ConsoleMetricExporter())],
    )
    metrics.set_meter_provider(meter_provider)
