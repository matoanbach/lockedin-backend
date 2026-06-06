from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.orm import sessionmaker

import lockedin_backend.models  # noqa: F401
from lockedin_backend.app.main import create_app
from lockedin_backend.db.base import Base


@pytest.fixture
def session_factory(tmp_path) -> Generator[sessionmaker, None, None]:
    database_url = f"sqlite:///{tmp_path / 'test.db'}"
    engine = create_engine(database_url, connect_args={"check_same_thread": False})
    factory = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)

    yield factory

    engine.dispose()


@pytest.fixture
def db_session(session_factory: sessionmaker) -> Generator[Session, None, None]:
    with session_factory() as session:
        yield session


@pytest.fixture
def client(session_factory: sessionmaker) -> Generator[TestClient, None, None]:
    app = create_app(session_factory=session_factory)

    with TestClient(app) as test_client:
        yield test_client
