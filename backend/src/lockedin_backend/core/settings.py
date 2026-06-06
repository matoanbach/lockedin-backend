from functools import lru_cache
from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


BASE_DIR = Path(__file__).resolve().parents[3]
DEFAULT_DATABASE_URL = f"sqlite:///{BASE_DIR / 'lockdin.db'}"


class Settings(BaseSettings):
    app_name: str = Field(default="LockdIn Backend")
    app_version: str = Field(default="0.1.0")
    debug: bool = Field(default=True)
    database_url: str = Field(default=DEFAULT_DATABASE_URL)

    model_config = SettingsConfigDict(
        env_file=BASE_DIR / ".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()
