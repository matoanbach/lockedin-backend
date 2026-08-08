from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class CurrentPrincipal:
    """Trusted account and tenant identity resolved by the authentication layer."""

    account_id: str
    profile_id: str
    issuer: str
    subject: str
    sid: str | None = None


@dataclass(frozen=True, slots=True)
class OperatorPrincipal:
    """Trusted operator scope for internal maintenance operations."""

    operator_id: str
    profile_id: str
