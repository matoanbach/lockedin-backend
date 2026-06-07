from __future__ import annotations

from datetime import date, datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo

from sqlalchemy.orm import Session

from lockedin_backend.repositories.preferences_repository import PreferencesRepository
from lockedin_backend.repositories.usage_daily_app_aggregate_repository import (
    UsageDailyAppAggregateRepository,
)
from lockedin_backend.repositories.usage_daily_category_aggregate_repository import (
    UsageDailyCategoryAggregateRepository,
)
from lockedin_backend.repositories.usage_repository import UsageRepository
from lockedin_backend.schemas.analytics import (
    CategoryBreakdownItem,
    DashboardAnalyticsResponse,
    HourlyUsagePoint,
    TopAppUsagePoint,
    TrendsAnalyticsResponse,
    WeeklySummaryResponse,
    WeeklyUsagePoint,
)
from lockedin_backend.services.profile_context import profile_context_service
from lockedin_backend.services.usage_time import ensure_utc, split_minutes_by_local_hour


def current_utc_now() -> datetime:
    return datetime.now(timezone.utc)


class AnalyticsService:
    def __init__(self) -> None:
        self.preferences_repository = PreferencesRepository()
        self.usage_repository = UsageRepository()
        self.app_aggregate_repository = UsageDailyAppAggregateRepository()
        self.category_aggregate_repository = UsageDailyCategoryAggregateRepository()

    def get_dashboard(self, db: Session) -> DashboardAnalyticsResponse:
        profile = profile_context_service.ensure_default_profile(db)
        effective_timezone = self._get_effective_timezone(db, profile.id)
        today = self._today_in_timezone(effective_timezone)
        week_dates = self._build_day_range(today, 7)
        daily_totals = self.category_aggregate_repository.get_daily_totals_for_date_range(
            db,
            profile.id,
            week_dates[0],
            week_dates[-1],
        )
        today_categories = self.category_aggregate_repository.list_by_date(db, profile.id, today)
        today_total = daily_totals.get(today, 0)
        yesterday_total = daily_totals.get(today - timedelta(days=1), 0)

        return DashboardAnalyticsResponse(
            today_total_minutes=today_total,
            category_breakdown=[
                CategoryBreakdownItem(name=row.category, minutes=row.total_minutes)
                for row in today_categories
            ],
            weekly_usage_hours=[self._minutes_to_hours(daily_totals.get(day, 0)) for day in week_dates],
            delta_from_yesterday_percent=self._calculate_delta_percent(
                current_total=today_total,
                previous_total=yesterday_total,
            ),
        )

    def get_trends(self, db: Session) -> TrendsAnalyticsResponse:
        profile = profile_context_service.ensure_default_profile(db)
        effective_timezone = self._get_effective_timezone(db, profile.id)
        timezone_value = ZoneInfo(effective_timezone)
        today = self._today_in_timezone(effective_timezone)
        week_dates = self._build_day_range(today, 7)
        daily_totals = self.category_aggregate_repository.get_daily_totals_for_date_range(
            db,
            profile.id,
            week_dates[0],
            week_dates[-1],
        )
        range_start = datetime.combine(week_dates[0], time.min, tzinfo=timezone_value).astimezone(
            timezone.utc
        )
        range_end = datetime.combine(
            today + timedelta(days=1),
            time.min,
            tzinfo=timezone_value,
        ).astimezone(timezone.utc)
        hourly_totals = [0] * 24

        for event in self.usage_repository.list_overlapping_range(
            db,
            profile.id,
            range_start,
            range_end,
        ):
            clipped_start = max(ensure_utc(event.started_at), range_start)
            clipped_end = min(ensure_utc(event.ended_at), range_end)
            for hour_index, minutes in split_minutes_by_local_hour(
                clipped_start,
                clipped_end,
                effective_timezone,
            ):
                hourly_totals[hour_index] += minutes

        top_apps = self.app_aggregate_repository.list_top_apps_for_date_range(
            db,
            profile.id,
            week_dates[0],
            week_dates[-1],
            limit=5,
        )

        return TrendsAnalyticsResponse(
            hourly_usage=[
                HourlyUsagePoint(hour=self._format_hour_label(hour), minutes=minutes)
                for hour, minutes in enumerate(hourly_totals)
            ],
            weekly_usage=[
                WeeklyUsagePoint(day=day.strftime("%a"), hours=self._minutes_to_hours(daily_totals.get(day, 0)))
                for day in week_dates
            ],
            top_apps=[
                TopAppUsagePoint(app_id=app_id, app_name=app_name, minutes=minutes)
                for app_id, app_name, minutes in top_apps
            ],
            peak_usage_window=self._build_peak_usage_window(hourly_totals),
        )

    def get_weekly_summary(self, db: Session) -> WeeklySummaryResponse:
        profile = profile_context_service.ensure_default_profile(db)
        effective_timezone = self._get_effective_timezone(db, profile.id)
        today = self._today_in_timezone(effective_timezone)
        current_week_dates = self._build_day_range(today, 7)
        previous_week_end = current_week_dates[0] - timedelta(days=1)
        previous_week_dates = self._build_day_range(previous_week_end, 7)
        current_totals = self.category_aggregate_repository.get_daily_totals_for_date_range(
            db,
            profile.id,
            current_week_dates[0],
            current_week_dates[-1],
        )
        previous_totals = self.category_aggregate_repository.get_daily_totals_for_date_range(
            db,
            profile.id,
            previous_week_dates[0],
            previous_week_dates[-1],
        )
        preferences = self.preferences_repository.get_by_profile_id(db, profile.id)
        daily_limit = preferences.default_daily_limit_minutes if preferences is not None else 0
        current_total_minutes = sum(current_totals.get(day, 0) for day in current_week_dates)
        previous_total_minutes = sum(previous_totals.get(day, 0) for day in previous_week_dates)
        all_daily_totals = self.category_aggregate_repository.list_all_daily_totals(db, profile.id)
        has_usage_history = bool(all_daily_totals)

        goals_met_days = 0
        longest_streak_days = 0
        if has_usage_history:
            goals_met_days = sum(
                1
                for day in current_week_dates
                if current_totals.get(day, 0) <= daily_limit
            )
            longest_streak_days = self._calculate_longest_streak(
                all_daily_totals,
                today=today,
                daily_limit=daily_limit,
            )

        return WeeklySummaryResponse(
            screen_time_reduction_percent=self._calculate_reduction_percent(
                current_total=current_total_minutes,
                previous_total=previous_total_minutes,
            ),
            total_week_hours=self._minutes_to_hours(current_total_minutes),
            daily_average_hours=self._minutes_to_hours(current_total_minutes / 7),
            goals_met_days=goals_met_days,
            longest_streak_days=longest_streak_days,
        )

    def _get_effective_timezone(self, db: Session, profile_id: str) -> str:
        return self.usage_repository.get_latest_timezone(db, profile_id) or "UTC"

    def _today_in_timezone(self, timezone_name: str) -> date:
        return current_utc_now().astimezone(ZoneInfo(timezone_name)).date()

    def _build_day_range(self, end_day: date, days: int) -> list[date]:
        start_day = end_day - timedelta(days=days - 1)
        return [start_day + timedelta(days=offset) for offset in range(days)]

    def _minutes_to_hours(self, minutes: float) -> float:
        return round(minutes / 60, 1)

    def _calculate_delta_percent(self, *, current_total: int, previous_total: int) -> int:
        if previous_total == 0:
            return 0
        return round(((current_total - previous_total) / previous_total) * 100)

    def _calculate_reduction_percent(self, *, current_total: int, previous_total: int) -> int:
        if previous_total == 0:
            return 0
        return round(((previous_total - current_total) / previous_total) * 100)

    def _build_peak_usage_window(self, hourly_totals: list[int]) -> str:
        if max(hourly_totals, default=0) == 0:
            return ""

        best_start_hour = 0
        best_total = -1
        for hour in range(24):
            window_total = hourly_totals[hour] + hourly_totals[(hour + 1) % 24]
            if window_total > best_total:
                best_total = window_total
                best_start_hour = hour

        return f"{self._format_hour_window_label(best_start_hour)} - {self._format_hour_window_label((best_start_hour + 2) % 24)}"

    def _format_hour_label(self, hour: int) -> str:
        if hour == 0:
            return "12am"
        if hour < 12:
            return f"{hour}am"
        if hour == 12:
            return "12pm"
        return f"{hour - 12}pm"

    def _format_hour_window_label(self, hour: int) -> str:
        if hour == 0:
            return "12 AM"
        if hour < 12:
            return f"{hour} AM"
        if hour == 12:
            return "12 PM"
        return f"{hour - 12} PM"

    def _calculate_longest_streak(
        self,
        all_daily_totals: list[tuple[date, int]],
        *,
        today: date,
        daily_limit: int,
    ) -> int:
        totals_by_day = {usage_date: total_minutes for usage_date, total_minutes in all_daily_totals}
        first_day = all_daily_totals[0][0]
        streak = 0
        longest_streak = 0
        current_day = first_day

        while current_day <= today:
            if totals_by_day.get(current_day, 0) <= daily_limit:
                streak += 1
                longest_streak = max(longest_streak, streak)
            else:
                streak = 0
            current_day += timedelta(days=1)

        return longest_streak


analytics_service = AnalyticsService()
