"""RAG agent FastAPI application."""

from shared.app import create_app
from shared.models import AgentType

app = create_app(agent_type=AgentType.RAG)
