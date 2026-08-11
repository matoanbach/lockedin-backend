from __future__ import annotations

import ssl
from contextlib import contextmanager
from threading import BoundedSemaphore
from typing import Any, Iterator
from urllib.parse import quote, urlsplit

import httpx

from lockedin_backend.core.settings import Settings


class KeycloakUnavailable(RuntimeError):
    """Raised when provider state cannot be established safely."""


class KeycloakRejected(RuntimeError):
    """Raised when Keycloak rejects a requested revocation operation."""


class KeycloakClient:
    """Bounded Keycloak back-channel client that never logs credential material."""

    _MAX_RESPONSE_BYTES = 65_536

    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self._slots = BoundedSemaphore(settings.keycloak_max_concurrent_requests)

    def _secret(self) -> str:
        configured = self.settings.keycloak_api_client_secret
        if configured is None or not configured.get_secret_value():
            raise KeycloakUnavailable("Keycloak API client secret is not configured")
        return configured.get_secret_value()

    def _verify(self) -> ssl.SSLContext | bool:
        if urlsplit(self.settings.keycloak_backchannel_server_url).scheme == "http":
            return True
        if self.settings.keycloak_ca_bundle is None:
            return True
        try:
            return ssl.create_default_context(cafile=str(self.settings.keycloak_ca_bundle))
        except OSError as exc:
            raise KeycloakUnavailable("Keycloak CA bundle is unavailable") from exc

    @contextmanager
    def _request_slot(self) -> Iterator[None]:
        acquired = self._slots.acquire(
            timeout=self.settings.keycloak_request_timeout_seconds
        )
        if not acquired:
            raise KeycloakUnavailable("Keycloak request capacity is exhausted")
        try:
            yield
        finally:
            self._slots.release()

    def _client(self) -> httpx.Client:
        return httpx.Client(
            timeout=httpx.Timeout(self.settings.keycloak_request_timeout_seconds),
            verify=self._verify(),
            follow_redirects=False,
        )

    def _json(self, response: httpx.Response) -> dict[str, Any]:
        if response.status_code != 200 or len(response.content) > self._MAX_RESPONSE_BYTES:
            raise KeycloakUnavailable("Unexpected Keycloak response")
        try:
            payload = response.json()
        except ValueError as exc:
            raise KeycloakUnavailable("Invalid Keycloak response") from exc
        if not isinstance(payload, dict):
            raise KeycloakUnavailable("Invalid Keycloak response")
        return payload

    def introspect(self, access_token: str) -> dict[str, Any]:
        try:
            with self._request_slot(), self._client() as client:
                response = client.post(
                    self.settings.keycloak_backchannel_introspection_url,
                    data={"token": access_token, "token_type_hint": "access_token"},
                    auth=httpx.BasicAuth(
                        self.settings.keycloak_api_client_id, self._secret()
                    ),
                    headers={"Accept": "application/json"},
                )
            return self._json(response)
        except KeycloakUnavailable:
            raise
        except httpx.HTTPError as exc:
            raise KeycloakUnavailable("Keycloak introspection failed") from exc

    def revoke_access_token(self, access_token: str) -> None:
        try:
            with self._request_slot(), self._client() as client:
                response = client.post(
                    self.settings.keycloak_backchannel_revocation_url,
                    data={
                        "token": access_token,
                        "token_type_hint": "access_token",
                        "client_id": self.settings.keycloak_mobile_client_id,
                    },
                )
        except (httpx.HTTPError, KeycloakUnavailable) as exc:
            raise KeycloakUnavailable("Keycloak token revocation failed") from exc
        if response.status_code != 200:
            raise KeycloakRejected("Keycloak rejected token revocation")

    def _service_account_token(self) -> str:
        try:
            with self._request_slot(), self._client() as client:
                response = client.post(
                    self.settings.keycloak_backchannel_token_url,
                    data={"grant_type": "client_credentials"},
                    auth=httpx.BasicAuth(
                        self.settings.keycloak_api_client_id, self._secret()
                    ),
                    headers={"Accept": "application/json"},
                )
            payload = self._json(response)
        except KeycloakUnavailable:
            raise
        except httpx.HTTPError as exc:
            raise KeycloakUnavailable("Keycloak service authentication failed") from exc
        token = payload.get("access_token")
        if not isinstance(token, str) or not token or len(token) > 16_384:
            raise KeycloakUnavailable("Invalid Keycloak service response")
        return token

    def logout_user(self, subject: str) -> None:
        service_token = self._service_account_token()
        url = f"{self._admin_user_url(subject)}/logout"
        try:
            with self._request_slot(), self._client() as client:
                response = client.post(
                    url,
                    headers={"Authorization": f"Bearer {service_token}"},
                )
        except (httpx.HTTPError, KeycloakUnavailable) as exc:
            raise KeycloakUnavailable("Keycloak user logout failed") from exc
        if response.status_code != 204:
            raise KeycloakRejected("Keycloak rejected user logout")

    def delete_user(self, subject: str) -> None:
        service_token = self._service_account_token()
        try:
            with self._request_slot(), self._client() as client:
                response = client.delete(
                    self._admin_user_url(subject),
                    headers={"Authorization": f"Bearer {service_token}"},
                )
        except (httpx.HTTPError, KeycloakUnavailable) as exc:
            raise KeycloakUnavailable("Keycloak user deletion failed") from exc
        if response.status_code != 204:
            raise KeycloakRejected("Keycloak rejected user deletion")

    def _admin_user_url(self, subject: str) -> str:
        return (
            f"{self.settings.keycloak_backchannel_server_url}/admin/realms/"
            f"{quote(self.settings.keycloak_realm, safe='')}/users/"
            f"{quote(subject, safe='')}"
        )

    def fetch_jwks(self) -> dict[str, Any]:
        try:
            with self._request_slot(), self._client() as client:
                response = client.get(
                    self.settings.keycloak_backchannel_jwks_url,
                    headers={"Accept": "application/json"},
                )
            payload = self._json(response)
        except KeycloakUnavailable:
            raise
        except httpx.HTTPError as exc:
            raise KeycloakUnavailable("Keycloak key retrieval failed") from exc
        keys = payload.get("keys")
        if not isinstance(keys, list) or not keys:
            raise KeycloakUnavailable("Keycloak returned no signing keys")
        return payload
