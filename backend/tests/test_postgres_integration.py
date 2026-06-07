from __future__ import annotations

import os

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from lockedin_backend.app.main import create_app


@pytest.mark.skipif(
    not os.getenv("TEST_DATABASE_URL"),
    reason="TEST_DATABASE_URL is required for Postgres integration tests",
)
def test_postgres_seeded_stack_smoke() -> None:
    database_url = os.environ["TEST_DATABASE_URL"]
    engine = create_engine(database_url)
    session_factory = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    app = create_app(session_factory=session_factory)

    try:
        with TestClient(app) as client:
            health_response = client.get("/api/v1/health")
            rules_response = client.get("/api/v1/rules")
            rule_status_response = client.get("/api/v1/rules/status")

        assert health_response.status_code == 200
        assert rules_response.status_code == 200
        assert rule_status_response.status_code == 200
        assert len(rules_response.json()) == 3
        assert len(rule_status_response.json()) == 3
    finally:
        engine.dispose()
