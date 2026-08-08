from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.orm import sessionmaker

import lockedin_backend.models  # noqa: F401
from lockedin_backend.api.dependencies.principal import (
    get_current_principal,
    get_operator_principal,
)
from lockedin_backend.app.main import create_app
from lockedin_backend.core.principal import CurrentPrincipal, OperatorPrincipal
from lockedin_backend.db.base import Base
from lockedin_backend.models import Account, ExternalIdentity, Preferences, Profile


TEST_ACCOUNT_ID = "10000000-0000-0000-0000-000000000001"
TEST_PROFILE_ID = "10000000-0000-0000-0000-000000000002"
TEST_ISSUER = "https://issuer.test/realms/lockdin"
TEST_SUBJECT = "synthetic-account-a"


@pytest.fixture
def current_principal() -> CurrentPrincipal:
    return CurrentPrincipal(
        account_id=TEST_ACCOUNT_ID,
        profile_id=TEST_PROFILE_ID,
        issuer=TEST_ISSUER,
        subject=TEST_SUBJECT,
        sid="synthetic-session-a",
    )


@pytest.fixture
def test_profile_id() -> str:
    return TEST_PROFILE_ID


@pytest.fixture
def session_factory(tmp_path) -> Generator[sessionmaker, None, None]:
    database_url = f"sqlite:///{tmp_path / 'test.db'}"
    engine = create_engine(database_url, connect_args={"check_same_thread": False})
    factory = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)

    with factory() as session:
        session.add(
            Profile(
                id=TEST_PROFILE_ID,
                slug="synthetic-account-a",
                name="Synthetic Account A",
                is_demo=False,
                is_active=True,
            )
        )
        session.add(
            Account(id=TEST_ACCOUNT_ID, profile_id=TEST_PROFILE_ID, enabled=True)
        )
        session.add(
            ExternalIdentity(
                account_id=TEST_ACCOUNT_ID,
                issuer=TEST_ISSUER,
                subject=TEST_SUBJECT,
            )
        )
        session.add(Preferences(profile_id=TEST_PROFILE_ID))
        session.commit()

    yield factory

    engine.dispose()


@pytest.fixture
def db_session(session_factory: sessionmaker) -> Generator[Session, None, None]:
    with session_factory() as session:
        yield session


@pytest.fixture
def client(
    session_factory: sessionmaker, current_principal: CurrentPrincipal
) -> Generator[TestClient, None, None]:
    app = create_app(session_factory=session_factory)
    app.dependency_overrides[get_current_principal] = lambda: current_principal

    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture
def operator_client(
    session_factory: sessionmaker, current_principal: CurrentPrincipal
) -> Generator[TestClient, None, None]:
    app = create_app(session_factory=session_factory)
    app.dependency_overrides[get_current_principal] = lambda: current_principal
    app.dependency_overrides[get_operator_principal] = lambda: OperatorPrincipal(
        operator_id="synthetic-operator",
        profile_id=current_principal.profile_id,
    )

    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture
def unauthenticated_client(
    session_factory: sessionmaker,
) -> Generator[TestClient, None, None]:
    app = create_app(session_factory=session_factory)

    with TestClient(app) as test_client:
        yield test_client
