from __future__ import annotations

from datetime import date, datetime, timezone
from zoneinfo import ZoneInfo

from sqlalchemy.orm import Session

from lockedin_backend.repositories.rule_repository import RuleRepository
from lockedin_backend.repositories.usage_daily_app_aggregate_repository import (
    UsageDailyAppAggregateRepository,
)
from lockedin_backend.repositories.usage_repository import UsageRepository
from lockedin_backend.schemas.rule_status import RuleStatusResponse
from lockedin_backend.services.app_identity import app_id_variants
from lockedin_backend.services.profile_context import profile_context_service


def current_utc_now() -> datetime:
    return datetime.now(timezone.utc)


class RuleStatusService:
    def __init__(self) -> None:
        self.rule_repository = RuleRepository()
        self.usage_repository = UsageRepository()
        self.app_aggregate_repository = UsageDailyAppAggregateRepository()

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
        used_minutes_by_app_id = self.app_aggregate_repository.get_daily_minutes_by_app_ids(
            db,
            profile.id,
            today,
            requested_app_ids,
        )

        return [
            self._build_response(
                rule,
                today,
                sum(used_minutes_by_app_id.get(app_id, 0) for app_id in app_id_variants(rule.app_id)),
            )
            for rule in rules
        ]

    def _build_response(
        self, rule, today: date, used_minutes: int
    ) -> RuleStatusResponse:
        if not rule.enabled:
            return RuleStatusResponse(
                rule_id=rule.id,
                app_id=rule.app_id,
                app_name=rule.app_name,
                usage_date=today.isoformat(),
                enabled=rule.enabled,
                limit_minutes=rule.limit_minutes,
                used_minutes=used_minutes,
                remaining_minutes=max(0, rule.limit_minutes - used_minutes),
                progress_percent=self._progress_percent(used_minutes, rule.limit_minutes),
                status="disabled",
                is_blocked_now=False,
            )

        status = self._status_for_usage(used_minutes, rule.limit_minutes)
        return RuleStatusResponse(
            rule_id=rule.id,
            app_id=rule.app_id,
            app_name=rule.app_name,
            usage_date=today.isoformat(),
            enabled=rule.enabled,
            limit_minutes=rule.limit_minutes,
            used_minutes=used_minutes,
            remaining_minutes=max(0, rule.limit_minutes - used_minutes),
            progress_percent=self._progress_percent(used_minutes, rule.limit_minutes),
            status=status,
            is_blocked_now=status == "over_limit",
        )

    def _progress_percent(self, used_minutes: int, limit_minutes: int) -> int:
        return round((used_minutes / limit_minutes) * 100) if limit_minutes > 0 else 0

    def _status_for_usage(self, used_minutes: int, limit_minutes: int) -> str:
        if used_minutes > limit_minutes:
            return "over_limit"
        if used_minutes == limit_minutes:
            return "at_limit"
        if used_minutes >= round(limit_minutes * 0.8):
            return "approaching_limit"
        return "under_limit"


rule_status_service = RuleStatusService()
