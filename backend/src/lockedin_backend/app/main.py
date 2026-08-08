from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import sessionmaker

from lockedin_backend.api.router import api_router
from lockedin_backend.app.docs_site import mount_docs_site
from lockedin_backend.core.settings import get_settings
from lockedin_backend.core.settings import Settings
from lockedin_backend.db.session import get_session_factory
from lockedin_backend.services.keycloak_client import KeycloakClient


def create_app(
    session_factory: sessionmaker | None = None,
    *,
    app_settings: Settings | None = None,
    keycloak_client: KeycloakClient | None = None,
) -> FastAPI:
    settings = app_settings or get_settings()
    resolved_session_factory = session_factory or get_session_factory()

    app = FastAPI(
        title=settings.app_name,
        version=settings.app_version,
        debug=settings.debug,
        docs_url="/api/docs",
        redoc_url="/api/redoc",
        openapi_url="/openapi.json",
        swagger_ui_oauth2_redirect_url="/api/docs/oauth2-redirect",
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origin_regex=settings.cors_allowed_origin_regex,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    mount_docs_site(app)
    app.state.session_factory = resolved_session_factory
    app.state.settings = settings
    app.state.keycloak_client = keycloak_client or KeycloakClient(settings)
    app.include_router(api_router)

    @app.get("/", tags=["root"])
    def read_root() -> dict[str, str]:
        return {"message": f"{settings.app_name} is running"}

    return app


app = create_app()
