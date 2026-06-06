from __future__ import annotations

from enum import StrEnum

from pydantic import Field

from lockedin_backend.core.constants import (
    MAX_TEXT_SIZE_PERCENT,
    MIN_TEXT_SIZE_PERCENT,
)
from lockedin_backend.core.serialization import APIModel


class NotificationTone(StrEnum):
    FUN = "fun"
    EDGY = "edgy"
    PROFESSIONAL = "professional"


class AccessibilitySettings(APIModel):
    text_size_percent: int
    high_contrast: bool
    large_tap_targets: bool


class PreferencesResponse(APIModel):
    has_completed_onboarding: bool
    default_daily_limit_minutes: int
    notification_tone: NotificationTone
    accessibility: AccessibilitySettings


class PreferencesUpdate(APIModel):
    has_completed_onboarding: bool | None = None
    default_daily_limit_minutes: int | None = Field(default=None, gt=0)
    notification_tone: NotificationTone | None = None
    text_size_percent: int | None = Field(
        default=None,
        ge=MIN_TEXT_SIZE_PERCENT,
        le=MAX_TEXT_SIZE_PERCENT,
    )
    high_contrast: bool | None = None
    large_tap_targets: bool | None = None
