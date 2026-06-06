from sqlalchemy.orm import Session

from lockedin_backend.models import Preferences
from lockedin_backend.repositories.preferences_repository import PreferencesRepository
from lockedin_backend.schemas.preferences import (
    AccessibilitySettings,
    PreferencesResponse,
    PreferencesUpdate,
)
from lockedin_backend.services.profile_context import profile_context_service


class PreferencesService:
    def __init__(self) -> None:
        self.repository = PreferencesRepository()

    def get_preferences(self, db: Session) -> PreferencesResponse:
        preferences = self._get_preferences_model(db)
        return self._to_response(preferences)

    def update_preferences(self, db: Session, payload: PreferencesUpdate) -> PreferencesResponse:
        preferences = self._get_preferences_model(db)
        updates = payload.model_dump(exclude_none=True)

        for field, value in updates.items():
            setattr(preferences, field, value)

        db.commit()
        db.refresh(preferences)
        return self._to_response(preferences)

    def _get_preferences_model(self, db: Session) -> Preferences:
        profile = profile_context_service.ensure_default_profile(db)
        preferences = self.repository.get_by_profile_id(db, profile.id)
        if preferences is None:
            preferences = self.repository.create(db, profile.id)
            db.commit()
            db.refresh(preferences)
        return preferences

    def _to_response(self, preferences: Preferences) -> PreferencesResponse:
        return PreferencesResponse(
            has_completed_onboarding=preferences.has_completed_onboarding,
            default_daily_limit_minutes=preferences.default_daily_limit_minutes,
            notification_tone=preferences.notification_tone,
            accessibility=AccessibilitySettings(
                text_size_percent=preferences.text_size_percent,
                high_contrast=preferences.high_contrast,
                large_tap_targets=preferences.large_tap_targets,
            ),
        )


preferences_service = PreferencesService()
