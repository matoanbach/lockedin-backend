from contextlib import asynccontextmanager

from fastapi import FastAPI
from sqlalchemy.orm import sessionmaker

from lockedin_backend.api.router import api_router
from lockedin_backend.app.docs_site import mount_docs_site
from lockedin_backend.core.settings import get_settings
from lockedin_backend.db.session import get_session_factory
from lockedin_backend.services.profile_context import profile_context_service


settings = get_settings()


def create_app(session_factory: sessionmaker | None = None) -> FastAPI:
    resolved_session_factory = session_factory or get_session_factory()

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        with resolved_session_factory() as db:
            profile_context_service.ensure_default_profile(db)
        yield

    app = FastAPI(
        title=settings.app_name,
        version=settings.app_version,
        debug=settings.debug,
        lifespan=lifespan,
        docs_url="/api/docs",
        redoc_url="/api/redoc",
        openapi_url="/openapi.json",
        swagger_ui_oauth2_redirect_url="/api/docs/oauth2-redirect",
    )
    mount_docs_site(app)
    app.state.session_factory = resolved_session_factory
    app.include_router(api_router)

    @app.get("/", tags=["root"])
    def read_root() -> dict[str, str]:
        return {"message": f"{settings.app_name} is running"}

    return app


app = create_app()
