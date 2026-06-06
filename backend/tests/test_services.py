import pytest

from lockedin_backend.core.constants import DEFAULT_PROFILE_SLUG
from lockedin_backend.core.errors import ConflictError, NotFoundError
from lockedin_backend.repositories.accountability_repository import AccountabilityRepository
from lockedin_backend.repositories.preferences_repository import PreferencesRepository
from lockedin_backend.repositories.profile_repository import ProfileRepository
from lockedin_backend.schemas.accountability import AccountabilityContactCreate
from lockedin_backend.schemas.rules import RuleCreate, RuleUpdate
from lockedin_backend.services.accountability_service import accountability_service
from lockedin_backend.services.preferences_service import preferences_service
from lockedin_backend.services.profile_context import profile_context_service
from lockedin_backend.services.rules_service import rules_service


def test_ensure_default_profile_is_idempotent_and_seeds_preferences(db_session) -> None:
    first_profile = profile_context_service.ensure_default_profile(db_session)
    second_profile = profile_context_service.ensure_default_profile(db_session)

    profile_repository = ProfileRepository()
    preferences_repository = PreferencesRepository()

    stored_profile = profile_repository.get_by_slug(db_session, DEFAULT_PROFILE_SLUG)
    stored_preferences = preferences_repository.get_by_profile_id(db_session, first_profile.id)

    assert first_profile.id == second_profile.id
    assert stored_profile is not None
    assert stored_profile.id == first_profile.id
    assert stored_preferences is not None


def test_preferences_service_recreates_missing_preferences_row(db_session) -> None:
    profile = profile_context_service.ensure_default_profile(db_session)
    preferences = PreferencesRepository().get_by_profile_id(db_session, profile.id)

    db_session.delete(preferences)
    db_session.commit()

    response = preferences_service.get_preferences(db_session)
    recreated_preferences = PreferencesRepository().get_by_profile_id(db_session, profile.id)

    assert response.default_daily_limit_minutes == 180
    assert recreated_preferences is not None


def test_rules_service_raises_not_found_for_missing_rule(db_session) -> None:
    with pytest.raises(NotFoundError):
        rules_service.update_rule(db_session, "missing-rule", RuleUpdate(limit_minutes=30))

    with pytest.raises(NotFoundError):
        rules_service.delete_rule(db_session, "missing-rule")


def test_rules_service_duplicate_app_id_raises_conflict(db_session) -> None:
    payload = RuleCreate(
        app_id="com.youtube.android",
        app_name="YouTube",
        limit_minutes=60,
        enabled=True,
    )

    rules_service.create_rule(db_session, payload)

    with pytest.raises(ConflictError):
        rules_service.create_rule(db_session, payload)


def test_accountability_service_normalizes_email_and_derives_name(db_session) -> None:
    response = accountability_service.create_contact(
        db_session,
        AccountabilityContactCreate(email="Buddy@Example.com", consent_confirmed=True),
    )

    stored_contact = AccountabilityRepository().get_by_email(
        db_session,
        profile_context_service.ensure_default_profile(db_session).id,
        "buddy@example.com",
    )

    assert response.email == "buddy@example.com"
    assert response.name == "buddy"
    assert stored_contact is not None


def test_accountability_service_duplicate_normalized_email_raises_conflict(db_session) -> None:
    accountability_service.create_contact(
        db_session,
        AccountabilityContactCreate(email="Friend@Example.com", consent_confirmed=False),
    )

    with pytest.raises(ConflictError):
        accountability_service.create_contact(
            db_session,
            AccountabilityContactCreate(email="friend@example.com", consent_confirmed=True),
        )
