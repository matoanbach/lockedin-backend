from __future__ import annotations

import os
from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import PlainTextResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles


ENV_DOCS_SITE_DIR = "LOCKDIN_DOCS_SITE_DIR"


def mount_docs_site(app: FastAPI) -> None:
    site_dir = _resolve_site_dir()

    @app.get("/docs", include_in_schema=False)
    def docs_redirect() -> RedirectResponse:
        return RedirectResponse(url="/docs/")

    if site_dir.exists() and site_dir.is_dir():
        app.mount("/docs", StaticFiles(directory=str(site_dir), html=True), name="docs")
        return

    @app.get("/docs/", include_in_schema=False)
    def docs_missing() -> PlainTextResponse:
        message = (
            "Docs site not built.\n\n"
            f"Expected: {site_dir}\n\n"
            "Build it with:\n"
            "  make build-docs\n"
            "or:\n"
            "  python -m mkdocs build -f conf/mkdocs.yml\n"
        )
        return PlainTextResponse(content=message, status_code=404)


def _resolve_site_dir() -> Path:
    docs_dir = os.getenv(ENV_DOCS_SITE_DIR)
    if docs_dir and docs_dir.strip():
        return Path(docs_dir).expanduser().resolve()
    return (Path.cwd().resolve() / ".artifacts" / "docs_site").resolve()
