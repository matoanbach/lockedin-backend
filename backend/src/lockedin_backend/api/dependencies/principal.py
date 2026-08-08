from fastapi import HTTPException, status

from lockedin_backend.core.principal import CurrentPrincipal, OperatorPrincipal


def get_current_principal() -> CurrentPrincipal:
    """Fail closed until Phase C installs the Keycloak authenticator."""

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Authentication required",
        headers={"WWW-Authenticate": "Bearer"},
    )


def get_operator_principal() -> OperatorPrincipal:
    """Fail closed until an internal operator mechanism is configured."""

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Operator authorization required",
    )
