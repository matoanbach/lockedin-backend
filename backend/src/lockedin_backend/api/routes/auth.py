from __future__ import annotations

from datetime import datetime, timezone
from typing import Annotated
from urllib.parse import parse_qs

from fastapi import APIRouter, Depends, Header, HTTPException, Request, Response, status
from sqlalchemy.orm import Session

from lockedin_backend.api.dependencies.principal import (
    get_bearer_token,
    get_current_principal,
)
from lockedin_backend.core.authentication import InvalidAccessToken, verify_recent_id_token
from lockedin_backend.core.principal import CurrentPrincipal
from lockedin_backend.core.provider_events import (
    InvalidProviderEvent,
    verify_backchannel_logout_token,
    verify_provider_event_signature,
)
from lockedin_backend.db.session import get_db
from lockedin_backend.schemas.auth import (
    AuthConfigResponse,
    ProviderSecurityEventRequest,
    SessionResponse,
)
from lockedin_backend.services.identity_service import (
    AccountDeletionService,
    PrincipalRejected,
    SessionService,
)
from lockedin_backend.services.keycloak_client import KeycloakRejected, KeycloakUnavailable


public_router = APIRouter(prefix="/auth", tags=["authentication"])
protected_router = APIRouter(prefix="/auth", tags=["authentication"])


def _provider_unavailable() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail="Authentication service unavailable",
    )


@public_router.get("/config", response_model=AuthConfigResponse)
def auth_config(request: Request) -> AuthConfigResponse:
    settings = request.app.state.settings
    return AuthConfigResponse(
        issuer=settings.keycloak_issuer,
        authorization_endpoint=settings.keycloak_authorization_url,
        token_endpoint=settings.keycloak_token_url,
        end_session_endpoint=settings.keycloak_end_session_url,
        client_id=settings.keycloak_mobile_client_id,
        redirect_uri=settings.keycloak_redirect_uri,
        scopes=["openid", "profile", "email"],
    )


@protected_router.get(
    "/session",
    response_model=SessionResponse,
    responses={401: {"description": "Authentication required"}, 503: {"description": "Authentication service unavailable"}},
)
def session(principal: Annotated[CurrentPrincipal, Depends(get_current_principal)]) -> SessionResponse:
    if principal.sid is None:
        raise HTTPException(status_code=401, detail="Authentication required")
    return SessionResponse(
        account_id=principal.account_id,
        profile_id=principal.profile_id,
        issuer=principal.issuer,
        subject=principal.subject,
        sid=principal.sid,
    )


@protected_router.post(
    "/logout",
    status_code=status.HTTP_204_NO_CONTENT,
    responses={401: {"description": "Authentication required"}, 503: {"description": "Authentication service unavailable"}},
)
def logout(
    request: Request,
    principal: Annotated[CurrentPrincipal, Depends(get_current_principal)],
    access_token: Annotated[str, Depends(get_bearer_token)],
    db: Annotated[Session, Depends(get_db)],
) -> Response:
    outcome = "success"
    try:
        request.app.state.keycloak_client.revoke_access_token(access_token)
    except (KeycloakUnavailable, KeycloakRejected):
        outcome = "local_only_provider_failed"
    SessionService(
        session_max_seconds=request.app.state.settings.keycloak_session_max_seconds
    ).revoke_current_session(db, principal, outcome=outcome)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@protected_router.post(
    "/logout-all",
    status_code=status.HTTP_204_NO_CONTENT,
    responses={401: {"description": "Authentication required"}, 503: {"description": "Authentication service unavailable"}},
)
def logout_all(
    request: Request,
    principal: Annotated[CurrentPrincipal, Depends(get_current_principal)],
    db: Annotated[Session, Depends(get_db)],
) -> Response:
    service = SessionService(
        session_max_seconds=request.app.state.settings.keycloak_session_max_seconds
    )
    audit_event = service.revoke_all_sessions(db, principal, outcome="provider_pending")
    try:
        request.app.state.keycloak_client.logout_user(principal.subject)
    except (KeycloakUnavailable, KeycloakRejected) as exc:
        service.set_audit_outcome(db, audit_event, "local_applied_provider_failed")
        raise _provider_unavailable() from exc
    service.set_audit_outcome(db, audit_event, "success")
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@protected_router.delete(
    "/account",
    status_code=status.HTTP_204_NO_CONTENT,
    responses={
        401: {"description": "Authentication required"},
        409: {"description": "Reauthenticated account mismatch"},
        503: {"description": "Authentication service unavailable"},
    },
)
def delete_account(
    request: Request,
    principal: Annotated[CurrentPrincipal, Depends(get_current_principal)],
    db: Annotated[Session, Depends(get_db)],
    expected_account_id: Annotated[str, Header(alias="X-LockdIn-Account-Id")],
    reauthentication_proof: Annotated[str, Header(alias="X-LockdIn-ID-Token")],
) -> Response:
    if expected_account_id != principal.account_id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Reauthenticated account does not match the active account",
        )
    try:
        verify_recent_id_token(
            reauthentication_proof,
            request.app.state.keycloak_client.fetch_jwks(),
            request.app.state.settings,
            expected_subject=principal.subject,
        )
        request.app.state.keycloak_client.delete_user(principal.subject)
    except (KeycloakUnavailable, KeycloakRejected) as exc:
        raise _provider_unavailable() from exc
    except InvalidAccessToken as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Recent reauthentication is required",
        ) from exc
    AccountDeletionService().delete_account(db, principal)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


async def _single_logout_token(request: Request) -> str:
    content_type = request.headers.get("content-type", "").split(";", 1)[0].strip().lower()
    if content_type != "application/x-www-form-urlencoded":
        raise InvalidProviderEvent("Invalid logout request")
    content_length = request.headers.get("content-length")
    if content_length is not None:
        try:
            if int(content_length) > 20_000:
                raise InvalidProviderEvent("Invalid logout request")
        except ValueError as exc:
            raise InvalidProviderEvent("Invalid logout request") from exc
    body = await request.body()
    if len(body) > 20_000:
        raise InvalidProviderEvent("Invalid logout request")
    try:
        values = parse_qs(
            body.decode("ascii"),
            keep_blank_values=True,
            strict_parsing=True,
            max_num_fields=2,
        )
    except (UnicodeDecodeError, ValueError) as exc:
        raise InvalidProviderEvent("Invalid logout request") from exc
    if set(values) != {"logout_token"} or len(values["logout_token"]) != 1:
        raise InvalidProviderEvent("Invalid logout request")
    return values["logout_token"][0]


@public_router.post(
    "/backchannel-logout",
    status_code=status.HTTP_204_NO_CONTENT,
    responses={400: {"description": "Invalid provider event"}, 503: {"description": "Authentication service unavailable"}},
)
async def backchannel_logout(
    request: Request,
    db: Annotated[Session, Depends(get_db)],
) -> Response:
    try:
        logout_token = await _single_logout_token(request)
        jwks = request.app.state.keycloak_client.fetch_jwks()
        claims = verify_backchannel_logout_token(
            logout_token, jwks, request.app.state.settings
        )
        SessionService(
            session_max_seconds=request.app.state.settings.keycloak_session_max_seconds
        ).process_backchannel_logout(
            db,
            issuer=claims.issuer,
            subject=claims.subject,
            sid=claims.sid,
            provider_event_id=claims.event_id,
            occurred_at=claims.occurred_at,
        )
    except KeycloakUnavailable as exc:
        raise _provider_unavailable() from exc
    except (InvalidProviderEvent, PrincipalRejected):
        raise HTTPException(status_code=400, detail="Invalid provider event")
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@public_router.post(
    "/provider-events",
    status_code=status.HTTP_204_NO_CONTENT,
    responses={400: {"description": "Invalid provider event"}, 503: {"description": "Authentication service unavailable"}},
)
def provider_event(
    request: Request,
    payload: ProviderSecurityEventRequest,
    db: Annotated[Session, Depends(get_db)],
    signature: Annotated[str | None, Header(alias="X-LockdIn-Event-Signature")] = None,
) -> Response:
    settings = request.app.state.settings
    configured_secret = settings.keycloak_event_webhook_secret
    if configured_secret is None:
        raise _provider_unavailable()
    try:
        if payload.issuer != settings.keycloak_issuer or signature is None:
            raise InvalidProviderEvent("Invalid provider event")
        verify_provider_event_signature(
            event_id=payload.event_id,
            occurred_at=payload.occurred_at,
            issuer=payload.issuer,
            subject=payload.subject,
            action=payload.action,
            signature=signature,
            secret=configured_secret.get_secret_value(),
            max_age_seconds=settings.keycloak_event_max_age_seconds,
        )
        service = SessionService(
            session_max_seconds=settings.keycloak_session_max_seconds
        )
        account_id, audit_event = service.process_provider_event(
            db,
            issuer=payload.issuer,
            subject=payload.subject,
            action=payload.action,
            provider_event_id=payload.event_id,
            occurred_at=datetime.fromtimestamp(payload.occurred_at, timezone.utc),
        )
    except (InvalidProviderEvent, PrincipalRejected):
        raise HTTPException(status_code=400, detail="Invalid provider event")
    if audit_event is None or account_id is None:
        return Response(status_code=status.HTTP_204_NO_CONTENT)
    if payload.action == "logout_all":
        service.set_audit_outcome(db, audit_event, "success")
        return Response(status_code=status.HTTP_204_NO_CONTENT)
    try:
        request.app.state.keycloak_client.logout_user(payload.subject)
    except (KeycloakUnavailable, KeycloakRejected) as exc:
        service.set_audit_outcome(db, audit_event, "local_applied_provider_failed")
        raise _provider_unavailable() from exc
    service.set_audit_outcome(db, audit_event, "success")
    return Response(status_code=status.HTTP_204_NO_CONTENT)
