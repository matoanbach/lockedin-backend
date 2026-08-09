import json
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
REALM_PATH = REPOSITORY_ROOT / "infrastructure" / "keycloak" / "lockdin-realm.json"


def _realm() -> dict:
    return json.loads(REALM_PATH.read_text(encoding="utf-8"))


def _client(realm: dict, client_id: str) -> dict:
    return next(client for client in realm["clients"] if client["clientId"] == client_id)


def test_realm_security_and_lifetime_contract() -> None:
    realm = _realm()
    assert realm["realm"] == "lockdin"
    assert realm["enabled"] is True
    assert realm["registrationAllowed"] is True
    assert realm["verifyEmail"] is True
    assert realm["resetPasswordAllowed"] is True
    assert realm["rememberMe"] is False
    assert realm["accessTokenLifespan"] == 300
    assert realm["clientSessionIdleTimeout"] == 1800
    assert realm["clientSessionMaxLifespan"] == 28800
    assert realm["actionTokenGeneratedByUserLifespan"] == 900
    assert realm["actionTokenGeneratedByAdminLifespan"] == 900
    assert realm["revokeRefreshToken"] is True
    assert realm["refreshTokenMaxReuse"] == 0
    assert realm["defaultSignatureAlgorithm"] == "RS256"
    assert realm["bruteForceProtected"] is True
    assert realm["smtpServer"]["host"] == "mailpit"
    assert realm["smtpServer"]["port"] == "1025"


def test_mobile_client_is_public_pkce_with_exact_audience_and_no_offline_grant() -> None:
    mobile = _client(_realm(), "lockdin-mobile")
    assert mobile["publicClient"] is True
    assert mobile["standardFlowEnabled"] is True
    assert mobile["implicitFlowEnabled"] is False
    assert mobile["directAccessGrantsEnabled"] is False
    assert mobile["serviceAccountsEnabled"] is False
    assert mobile["redirectUris"] == ["com.lockdin.lockdinapp:/oauth2redirect"]
    assert mobile["defaultClientScopes"] == ["basic", "profile", "email"]
    assert mobile["optionalClientScopes"] == []
    assert mobile["attributes"]["pkce.code.challenge.method"] == "S256"
    assert (
        mobile["attributes"]["post.logout.redirect.uris"]
        == "com.lockdin.lockdinapp:/oauth2redirect"
    )
    assert mobile["attributes"]["oauth2.device.authorization.grant.enabled"] == "false"
    assert mobile["attributes"]["oidc.ciba.grant.enabled"] == "false"
    assert mobile["attributes"]["backchannel.logout.session.required"] == "true"
    mapper = mobile["protocolMappers"]
    assert len(mapper) == 1
    assert mapper[0]["protocolMapper"] == "oidc-audience-mapper"
    assert mapper[0]["config"]["included.client.audience"] == "lockdin-api"


def test_api_client_and_provider_event_contract_are_narrow() -> None:
    realm = _realm()
    api = _client(realm, "lockdin-api")
    assert api["publicClient"] is False
    assert api["secret"] == "${KEYCLOAK_API_CLIENT_SECRET}"
    assert api["standardFlowEnabled"] is False
    assert api["implicitFlowEnabled"] is False
    assert api["directAccessGrantsEnabled"] is False
    assert api["serviceAccountsEnabled"] is True
    service_account = next(
        user for user in realm["users"] if user.get("serviceAccountClientId") == "lockdin-api"
    )
    assert service_account["clientRoles"] == {"realm-management": ["manage-users"]}
    assert "lockdin-security-events" in realm["eventsListeners"]
    assert realm["enabledEventTypes"] == ["UPDATE_PASSWORD"]
    assert realm["adminEventsDetailsEnabled"] is False


def test_session_limiter_reset_and_compose_import_wiring() -> None:
    realm = _realm()
    limiter = next(
        item
        for item in realm["authenticatorConfig"]
        if item["alias"] == "LockdIn max three mobile sessions"
    )
    assert limiter["config"]["userClientLimit"] == "3"
    assert limiter["config"]["behavior"] == "Terminate oldest session"
    reset = next(
        item
        for item in realm["authenticatorConfig"]
        if item["alias"] == "LockdIn force login after reset"
    )
    assert reset["config"]["force-login"] == "true"
    assert realm["browserFlow"] == "LockdIn Browser"
    assert realm["resetCredentialsFlow"] == "LockdIn Reset Credentials"

    compose = (REPOSITORY_ROOT / "docker-compose.yml").read_text(encoding="utf-8")
    assert 'command: ["start", "--import-realm"]' in compose
    assert "./infrastructure/keycloak:/opt/keycloak/data/import:ro" in compose
    assert "KEYCLOAK_API_CLIENT_SECRET: ${KEYCLOAK_API_CLIENT_SECRET:?" in compose
    assert "KEYCLOAK_EVENT_WEBHOOK_SECRET: ${KEYCLOAK_EVENT_WEBHOOK_SECRET:?" in compose
    assert "KEYCLOAK_CA_BUNDLE_HOST_PATH:?" in compose


def test_browser_flow_nests_required_session_limit_after_authentication() -> None:
    realm = _realm()
    flows = {flow["alias"]: flow for flow in realm["authenticationFlows"]}

    browser = flows[realm["browserFlow"]]["authenticationExecutions"]
    assert {execution["requirement"] for execution in browser} == {"ALTERNATIVE"}
    assert browser[-1]["flowAlias"] == "LockdIn Authenticate With Session Limit"

    limited = flows["LockdIn Authenticate With Session Limit"][
        "authenticationExecutions"
    ]
    assert [execution["requirement"] for execution in limited] == [
        "REQUIRED",
        "REQUIRED",
    ]
    assert limited[0]["flowAlias"] == "LockdIn Real Authentication"
    assert limited[1]["authenticator"] == "user-session-limits"

    real_authentication = flows["LockdIn Real Authentication"][
        "authenticationExecutions"
    ]
    assert {execution["requirement"] for execution in real_authentication} == {
        "ALTERNATIVE"
    }
    assert real_authentication[-1]["flowAlias"] == "LockdIn Browser Forms"
