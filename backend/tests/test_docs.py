from __future__ import annotations

from fastapi.testclient import TestClient

from lockedin_backend.app.main import create_app


def test_docs_redirects_to_slash(client) -> None:
    response = client.get("/docs", follow_redirects=False)

    assert response.status_code == 307
    assert response.headers["location"] == "/docs/"


def test_docs_missing_site_returns_build_instructions(client) -> None:
    response = client.get("/docs/")

    assert response.status_code in {200, 404}


def test_docs_missing_site_returns_build_instructions_for_missing_dir(
    monkeypatch, session_factory, tmp_path
) -> None:
    missing_site_dir = tmp_path / "missing_docs_site"
    monkeypatch.setenv("LOCKDIN_DOCS_SITE_DIR", str(missing_site_dir))

    app = create_app(session_factory=session_factory)

    with TestClient(app) as client:
        response = client.get("/docs/")

    assert response.status_code == 404
    assert "Docs site not built." in response.text
    assert "make build-docs" in response.text


def test_swagger_ui_is_served_at_api_docs(client) -> None:
    response = client.get("/api/docs")

    assert response.status_code == 200
    assert "Swagger UI" in response.text


def test_built_docs_site_is_served(monkeypatch, session_factory, tmp_path) -> None:
    site_dir = tmp_path / "docs_site"
    site_dir.mkdir()
    (site_dir / "index.html").write_text("<html><body>LockdIn Docs</body></html>", encoding="utf-8")
    monkeypatch.setenv("LOCKDIN_DOCS_SITE_DIR", str(site_dir))

    app = create_app(session_factory=session_factory)

    with TestClient(app) as client:
        response = client.get("/docs/")

    assert response.status_code == 200
    assert "LockdIn Docs" in response.text
