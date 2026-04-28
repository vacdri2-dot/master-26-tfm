"""API key authentication dependency for agent HTTP APIs."""

import secrets
from collections.abc import Callable, Coroutine
from typing import Annotated, Any

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

Verifier = Callable[[HTTPAuthorizationCredentials | None], Coroutine[Any, Any, None]]


def build_api_key_dependency(expected_key: str) -> Verifier:
    """Return a FastAPI dependency that enforces ``Authorization: Bearer <expected_key>``.

    The expected key is captured at construction time, typically from an environment
    variable populated by a Key Vault secret reference in the Container App definition.
    Comparison is constant-time to avoid timing side channels.
    """
    if not expected_key:
        raise ValueError("expected_key must be a non-empty string")

    bearer_scheme = HTTPBearer(auto_error=False)

    async def verify(
        credentials: Annotated[
            HTTPAuthorizationCredentials | None, Depends(bearer_scheme)
        ],
    ) -> None:
        if credentials is None or credentials.scheme.lower() != "bearer":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Missing or malformed Authorization header",
                headers={"WWW-Authenticate": "Bearer"},
            )
        if not secrets.compare_digest(credentials.credentials, expected_key):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid API key",
                headers={"WWW-Authenticate": "Bearer"},
            )

    return verify
