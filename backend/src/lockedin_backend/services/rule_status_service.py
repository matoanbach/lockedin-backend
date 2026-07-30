from __future__ import annotations

from datetime import date, datetime, timezone
from zoneinfo import ZoneInfo

from sqlalchemy.orm import Session

from lockedin_backend.repositories.rule_repository import RuleRepository
from lockedin_backend.repositories.usage_repository import UsageRepository
from lockedin_backend.schemas.rule_status import RuleStatusResponse
from lockedin_backend.services.app_identity import app_id_variants
from lockedin_backend.services.profile_context import profile_context_service
from lockedin_backend.services.usage_time import (
    MILLISECONDS_PER_MINUTE,
    completed_minutes,
    split_milliseconds_by_local_date,
)


def current_utc_now() -> datetime:
    return datetime.now(timezone.utc)


class RuleStatusService:
    def __init__(self) -> None:
        self.rule_repository = RuleRepository()
        self.usage_repository = UsageRepository()

    def list_rule_statuses(self, db: Session) -> list[RuleStatusResponse]:
        profile = profile_context_service.ensure_default_profile(db)
        effective_timezone = self.usage_repository.get_latest_timezone(db, profile.id) or "UTC"
        today = current_utc_now().astimezone(ZoneInfo(effective_timezone)).date()
        rules = self.rule_repository.list_by_profile_id(db, profile.id)
        requested_app_ids = sorted({
            variant
            for rule in rules
            for variant in app_id_variants(rule.app_id)
        })
        used_milliseconds_by_app_id = {
            app_id: 0 for app_id in requested_app_ids
        }
        for event in self.usage_repository.list_all_for_profile(db, profile.id):
            if event.app_id not in used_milliseconds_by_app_id:
                continue
            for usage_date, milliseconds in split_milliseconds_by_local_date(
                event.started_at,
                event.ended_at,
                event.timezone,
            ):
                if usage_date == today:
                    used_milliseconds_by_app_id[event.app_id] += milliseconds

        return [
            self._build_response(
                rule,
                today,
                sum(
                    used_milliseconds_by_app_id.get(app_id, 0)
                    for app_id in app_id_variants(rule.app_id)
                ),
            )
            for rule in rules
        ]

    def _build_response(
        self, rule, today: date, used_milliseconds: int
    ) -> RuleStatusResponse:
        limit_milliseconds = rule.limit_minutes * MILLISECONDS_PER_MINUTE
        used_minutes = completed_minutes(used_milliseconds)
        remaining_milliseconds = max(0, limit_milliseconds - used_milliseconds)
        remaining_minutes = completed_minutes(remaining_milliseconds)
        if not rule.enabled:
            return RuleStatusResponse(
                rule_id=rule.id,
                app_id=rule.app_id,
                app_name=rule.app_name,
                usage_date=today.isoformat(),
                enabled=rule.enabled,
                limit_minutes=rule.limit_minutes,
                used_minutes=used_minutes,
                remaining_minutes=remaining_minutes,
                used_milliseconds=used_milliseconds,
                remaining_milliseconds=remaining_milliseconds,
                progress_percent=self._progress_percent(
                    used_milliseconds, limit_milliseconds
                ),
                status="disabled",
                is_blocked_now=False,
            )

        status = self._status_for_usage(used_milliseconds, limit_milliseconds)
        return RuleStatusResponse(
            rule_id=rule.id,
            app_id=rule.app_id,
            app_name=rule.app_name,
            usage_date=today.isoformat(),
            enabled=rule.enabled,
            limit_minutes=rule.limit_minutes,
            used_minutes=used_minutes,
            remaining_minutes=remaining_minutes,
            used_milliseconds=used_milliseconds,
            remaining_milliseconds=remaining_milliseconds,
            progress_percent=self._progress_percent(
                used_milliseconds, limit_milliseconds
            ),
            status=status,
            is_blocked_now=status in {"at_limit", "over_limit"},
        )

    def _progress_percent(
        self, used_milliseconds: int, limit_milliseconds: int
    ) -> int:
        if limit_milliseconds <= 0:
            return 0
        rounded_percent = round(
            (used_milliseconds / limit_milliseconds) * 100
        )
        if used_milliseconds < limit_milliseconds:
            return min(99, rounded_percent)
        return rounded_percent

    def _status_for_usage(
        self, used_milliseconds: int, limit_milliseconds: int
    ) -> str:
        if used_milliseconds > limit_milliseconds:
            return "over_limit"
        if used_milliseconds == limit_milliseconds:
            return "at_limit"
        if used_milliseconds * 5 >= limit_milliseconds * 4:
            return "approaching_limit"
        return "under_limit"


rule_status_service = RuleStatusService()
