from lockedin_backend.app.main import create_app
from lockedin_backend.core.settings import Settings


def test_app_metadata() -> None:
    app = create_app()

    assert app.title == "LockdIn Backend"
    assert app.version == "0.1.0"


def test_localhost_cors_preflight_is_allowed(client) -> None:
    response = client.options(
        "/api/v1/me/preferences",
        headers={
            "Origin": "http://localhost:50948",
            "Access-Control-Request-Method": "GET",
            "Access-Control-Request-Headers": "content-type",
        },
    )

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "http://localhost:50948"


def test_release_debug_value_is_treated_as_false() -> None:
    settings = Settings(debug="release")

    assert settings.debug is False
