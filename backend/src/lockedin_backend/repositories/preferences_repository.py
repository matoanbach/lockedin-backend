from sqlalchemy import select
from sqlalchemy.orm import Session

from lockedin_backend.models import Preferences


class PreferencesRepository:
    def get_by_profile_id(self, db: Session, profile_id: str) -> Preferences | None:
        return db.execute(
            select(Preferences).where(Preferences.profile_id == profile_id)
        ).scalar_one_or_none()

    def create(self, db: Session, profile_id: str) -> Preferences:
        preferences = Preferences(profile_id=profile_id)
        db.add(preferences)
        db.flush()
        return preferences
