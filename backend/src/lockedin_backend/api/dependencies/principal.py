from typing import Annotated

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from lockedin_backend.core.authentication import InvalidAccessToken, validate_introspection
from lockedin_backend.core.principal import CurrentPrincipal, OperatorPrincipal
from lockedin_backend.db.session import get_db
from lockedin_backend.services.identity_service import IdentityService, PrincipalRejected
from lockedin_backend.services.keycloak_client import KeycloakUnavailable


bearer_scheme = HTTPBearer(auto_error=False, scheme_name="KeycloakAccessToken")


def _authentication_required() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Authentication required",
        headers={"WWW-Authenticate": "Bearer"},
    )


def get_bearer_token(
    credentials: Annotated[
        HTTPAuthorizationCredentials | None, Depends(bearer_scheme)
    ],
) -> str:
    if (
        credentials is None
        or credentials.scheme.lower() != "bearer"
        or not credentials.credentials
    ):
        raise _authentication_required()
    return credentials.credentials


def get_current_principal(
    request: Request,
    access_token: Annotated[str, Depends(get_bearer_token)],
    db: Annotated[Session, Depends(get_db)],
) -> CurrentPrincipal:
    """Introspect every request and resolve its immutable provider identity."""

    settings = request.app.state.settings
    keycloak_client = request.app.state.keycloak_client
    try:
        payload = keycloak_client.introspect(access_token)
        claims = validate_introspection(access_token, payload, settings)
        return IdentityService().resolve_principal(db, claims)
    except KeycloakUnavailable as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Authentication service unavailable",
        ) from exc
    except (InvalidAccessToken, PrincipalRejected):
        raise _authentication_required()


def get_operator_principal() -> OperatorPrincipal:
    """Fail closed until an internal operator mechanism is configured."""

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Operator authorization required",
    )
