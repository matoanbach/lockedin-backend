from pathlib import Path

from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, inspect
from sqlalchemy.orm import sessionmaker

from lockedin_backend.app.main import create_app
from lockedin_backend.core.settings import get_settings


def test_alembic_upgrade_head_supports_app_startup(tmp_path, monkeypatch) -> None:
    backend_dir = Path(__file__).resolve().parents[1]
    database_path = tmp_path / "migrated.db"
    database_url = f"sqlite:///{database_path}"

    monkeypatch.setenv("DATABASE_URL", database_url)
    get_settings.cache_clear()

    alembic_config = Config(str(backend_dir / "alembic.ini"))
    alembic_config.set_main_option("script_location", str(backend_dir / "alembic"))
    alembic_config.set_main_option("sqlalchemy.url", database_url)

    command.upgrade(alembic_config, "head")

    engine = create_engine(database_url, connect_args={"check_same_thread": False})
    table_names = set(inspect(engine).get_table_names())
    session_factory = sessionmaker(autocommit=False, autoflush=False, bind=engine)

    app = create_app(session_factory=session_factory)

    with TestClient(app) as client:
        response = client.get("/api/v1/health")

    engine.dispose()
    get_settings.cache_clear()

    assert {"profiles", "preferences", "rules", "accountability_contacts"} <= table_names
    assert response.status_code == 200
