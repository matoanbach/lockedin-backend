from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone
from pathlib import Path
from uuid import uuid4

import pytest
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    MetaData,
    String,
    Table,
    create_engine,
    inspect,
    select,
    text,
)
from sqlalchemy.engine import make_url
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker

import lockedin_backend.models  # noqa: F401
from lockedin_backend.api.dependencies.principal import get_current_principal
from lockedin_backend.app.main import create_app
from lockedin_backend.core.principal import CurrentPrincipal
from lockedin_backend.db.base import Base
from lockedin_backend.models import Account, ExternalIdentity, Preferences, Profile


ADMIN_URL_ENV = "LOCKDIN_TEST_POSTGRES_ADMIN_URL"
BACKEND_ROOT = Path(__file__).resolve().parents[1]
LEGACY_TABLES = [
    "profiles",
    "preferences",
    "rules",
    "accountability_contacts",
    "usage_events",
    "usage_daily_app_aggregates",
    "usage_daily_category_aggregates",
    "enforcement_events",
]

pytestmark = pytest.mark.skipif(
    not os.getenv(ADMIN_URL_ENV),
    reason=f"{ADMIN_URL_ENV} is required for isolated PostgreSQL tests",
)


@pytest.fixture
def postgres_database_url() -> str:
    """Create a disposable database without touching an existing LockdIn database."""

    admin_url = make_url(os.environ[ADMIN_URL_ENV])
    database_name = f"lockdin_phase_c_{uuid4().hex}"
    admin_engine = create_engine(admin_url, isolation_level="AUTOCOMMIT")
    with admin_engine.connect() as connection:
        connection.exec_driver_sql(f'CREATE DATABASE "{database_name}"')

    database_url = admin_url.set(database=database_name)
    try:
        yield database_url.render_as_string(hide_password=False)
    finally:
        with admin_engine.connect() as connection:
            connection.execute(
                text(
                    "SELECT pg_terminate_backend(pid) FROM pg_stat_activity "
                    "WHERE datname = :database_name AND pid <> pg_backend_pid()"
                ),
                {"database_name": database_name},
            )
            connection.exec_driver_sql(f'DROP DATABASE "{database_name}"')
        admin_engine.dispose()


def _alembic_config(database_url: str) -> Config:
    config = Config(str(BACKEND_ROOT / "alembic.ini"))
    config.set_main_option("sqlalchemy.url", database_url.replace("%", "%%"))
    return config


def _create_legacy_schema(engine) -> None:
    metadata = MetaData(naming_convention=Base.metadata.naming_convention)
    Table(
        "profiles",
        metadata,
        Column("id", String(36), primary_key=True),
        Column("slug", String(50), nullable=False, unique=True),
        Column("name", String(100), nullable=False),
        Column("created_at", DateTime(timezone=True), nullable=False),
        Column("updated_at", DateTime(timezone=True), nullable=False),
    )
    for table_name in LEGACY_TABLES[1:]:
        Base.metadata.tables[table_name].to_metadata(metadata)
    metadata.create_all(engine)


def test_empty_database_migrates_to_head_and_enforces_ownership(
    postgres_database_url: str,
) -> None:
    command.upgrade(_alembic_config(postgres_database_url), "head")
    engine = create_engine(postgres_database_url)
    factory = sessionmaker(bind=engine)
    now = datetime.now(timezone.utc)
    try:
        inspector = inspect(engine)
        assert set(inspector.get_table_names()) >= {
            *LEGACY_TABLES,
            "accounts",
            "external_identities",
            "revoked_provider_sessions",
            "security_audit_events",
            "alembic_version",
        }
        assert {
            constraint["name"]
            for constraint in inspector.get_check_constraints(
                "revoked_provider_sessions"
            )
        } == {"ck_revoked_provider_sessions_expires_not_before_revocation"}
        with engine.connect() as connection:
            assert connection.scalar(text("SELECT version_num FROM alembic_version")) == (
                "20260808_02"
            )
        assert {
            index["name"]
            for index in inspector.get_indexes("security_audit_events")
        } >= {
            "ix_security_audit_events_account_created_at",
            "ix_security_audit_events_type_created_at",
        }
        assert {
            constraint["name"]
            for constraint in inspector.get_unique_constraints("security_audit_events")
        } == {"uq_security_audit_events_provider_event_id"}
        audit_foreign_keys = inspector.get_foreign_keys("security_audit_events")
        assert len(audit_foreign_keys) == 1
        assert audit_foreign_keys[0]["name"] == (
            "fk_security_audit_events_account_id_accounts"
        )
        assert audit_foreign_keys[0]["options"]["ondelete"] == "SET NULL"

        with factory() as session:
            demo = Profile(slug="default", name="Demo", is_demo=True, is_active=True)
            owned = Profile(slug="owned", name="Owned", is_demo=False, is_active=True)
            session.add_all([demo, owned])
            session.flush()
            session.add(Account(profile_id=owned.id, enabled=True))
            session.commit()

            session.add(Account(profile_id=demo.id, enabled=True))
            with pytest.raises(IntegrityError):
                session.commit()
            session.rollback()

            owned.is_demo = True
            with pytest.raises(IntegrityError):
                session.commit()
            session.rollback()

            session.add(
                ExternalIdentity(
                    account_id=session.scalar(
                        select(Account.id).where(Account.profile_id == owned.id)
                    ),
                    issuer="https://issuer.test/realms/lockdin",
                    subject="subject-a",
                )
            )
            session.commit()
    finally:
        engine.dispose()


def test_exact_legacy_schema_upgrades_without_rewriting_existing_rows(
    postgres_database_url: str,
) -> None:
    engine = create_engine(postgres_database_url)
    _create_legacy_schema(engine)
    now = datetime.now(timezone.utc)
    with engine.begin() as connection:
        connection.execute(
            text(
                "INSERT INTO profiles (id, slug, name, created_at, updated_at) "
                "VALUES (:id, 'default', 'Development Profile', :now, :now)"
            ),
            {"id": "00000000-0000-0000-0000-000000000001", "now": now},
        )
        connection.execute(
            text(
                "INSERT INTO preferences (id, profile_id, has_completed_onboarding, "
                "default_daily_limit_minutes, notification_tone, text_size_percent, "
                "high_contrast, large_tap_targets, created_at, updated_at) VALUES "
                "(:id, :profile_id, TRUE, 180, 'professional', 100, FALSE, FALSE, :now, :now)"
            ),
            {
                "id": "00000000-0000-0000-0000-000000000002",
                "profile_id": "00000000-0000-0000-0000-000000000001",
                "now": now,
            },
        )
    engine.dispose()

    command.upgrade(_alembic_config(postgres_database_url), "head")
    engine = create_engine(postgres_database_url)
    try:
        with engine.connect() as connection:
            assert connection.scalar(text("SELECT count(*) FROM profiles")) == 1
            assert connection.scalar(text("SELECT count(*) FROM preferences")) == 1
            assert connection.scalar(
                text("SELECT is_demo FROM profiles WHERE slug = 'default'")
            ) is True
            assert connection.scalar(text("SELECT version_num FROM alembic_version")) == (
                "20260808_02"
            )
    finally:
        engine.dispose()


def test_two_account_postgres_request_isolation(postgres_database_url: str) -> None:
    command.upgrade(_alembic_config(postgres_database_url), "head")
    engine = create_engine(postgres_database_url)
    factory = sessionmaker(bind=engine)
    issuer = "https://issuer.test/realms/lockdin"
    principals: list[CurrentPrincipal] = []
    try:
        with factory() as session:
            for label in ("a", "b"):
                profile = Profile(
                    slug=f"account-{label}",
                    name=f"Account {label.upper()}",
                    is_demo=False,
                    is_active=True,
                )
                session.add(profile)
                session.flush()
                account = Account(profile_id=profile.id, enabled=True)
                session.add(account)
                session.flush()
                session.add_all(
                    [
                        ExternalIdentity(
                            account_id=account.id,
                            issuer=issuer,
                            subject=f"subject-{label}",
                        ),
                        Preferences(profile_id=profile.id),
                    ]
                )
                principals.append(
                    CurrentPrincipal(
                        account_id=account.id,
                        profile_id=profile.id,
                        issuer=issuer,
                        subject=f"subject-{label}",
                        sid=f"session-{label}",
                    )
                )
            session.commit()

        app = create_app(session_factory=factory)
        selected = {"principal": principals[0]}
        app.dependency_overrides[get_current_principal] = lambda: selected["principal"]
        with TestClient(app) as client:
            created = client.post(
                "/api/v1/rules",
                json={
                    "appId": "com.example.focus",
                    "appName": "Focus A",
                    "limitMinutes": 30,
                },
            )
            assert created.status_code == 201
            rule_id = created.json()["id"]

            selected["principal"] = principals[1]
            assert client.get("/api/v1/rules").json() == []
            assert client.patch(
                f"/api/v1/rules/{rule_id}", json={"limitMinutes": 5}
            ).status_code == 404
            assert client.post(
                "/api/v1/rules",
                json={
                    "appId": "com.example.focus",
                    "appName": "Focus B",
                    "limitMinutes": 15,
                },
            ).status_code == 201

            selected["principal"] = principals[0]
            assert client.get("/api/v1/rules").json()[0]["limitMinutes"] == 30
    finally:
        engine.dispose()
