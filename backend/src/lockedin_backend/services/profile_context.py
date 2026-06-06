from sqlalchemy.orm import Session

from lockedin_backend.core.constants import DEFAULT_PROFILE_NAME, DEFAULT_PROFILE_SLUG
from lockedin_backend.models import Preferences, Profile
from lockedin_backend.repositories.preferences_repository import PreferencesRepository
from lockedin_backend.repositories.profile_repository import ProfileRepository


class ProfileContextService:
    def __init__(self) -> None:
        self.profile_repository = ProfileRepository()
        self.preferences_repository = PreferencesRepository()

    def ensure_default_profile(self, db: Session) -> Profile:
        profile = self.profile_repository.get_by_slug(db, DEFAULT_PROFILE_SLUG)
        created = False

        if profile is None:
            profile = self.profile_repository.create(
                db,
                slug=DEFAULT_PROFILE_SLUG,
                name=DEFAULT_PROFILE_NAME,
            )
            created = True

        preferences = self.preferences_repository.get_by_profile_id(db, profile.id)
        if preferences is None:
            self.preferences_repository.create(db, profile.id)
            created = True

        if created:
            db.commit()
            db.refresh(profile)

        return profile


profile_context_service = ProfileContextService()
