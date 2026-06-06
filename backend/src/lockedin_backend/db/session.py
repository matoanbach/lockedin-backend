from collections.abc import Generator
from functools import lru_cache

from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.orm.session import sessionmaker as SessionMaker

from fastapi import Request

from lockedin_backend.core.settings import get_settings


@lru_cache
def get_engine() -> Engine:
    settings = get_settings()
    return create_engine(
        settings.database_url,
        connect_args={"check_same_thread": False}
        if settings.database_url.startswith("sqlite")
        else {},
    )


@lru_cache
def get_session_factory() -> SessionMaker:
    return sessionmaker(autocommit=False, autoflush=False, bind=get_engine())


def get_db(request: Request) -> Generator[Session, None, None]:
    session_factory = getattr(request.app.state, "session_factory", get_session_factory())
    db = session_factory()
    try:
        yield db
    finally:
        db.close()
