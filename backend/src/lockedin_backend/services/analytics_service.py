from __future__ import annotations

from collections import defaultdict
from datetime import date, datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo

from sqlalchemy.orm import Session

from lockedin_backend.repositories.preferences_repository import PreferencesRepository
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
from lockedin_backend.services.app_classification import classify_app
from lockedin_backend.services.usage_time import (
    MILLISECONDS_PER_MINUTE,
    completed_minutes,
    ensure_utc,
    split_milliseconds_by_local_date,
    split_milliseconds_by_local_hour,
)


def current_utc_now() -> datetime:
    return datetime.now(timezone.utc)


class AnalyticsService:
    def __init__(self) -> None:
        self.preferences_repository = PreferencesRepository()
        self.usage_repository = UsageRepository()

    def get_dashboard(self, db: Session, profile_id: str) -> DashboardAnalyticsResponse:
        effective_timezone = self._get_effective_timezone(db, profile_id)
        today = self._today_in_timezone(effective_timezone)
        week_dates = self._build_day_range(today, 7)
        daily_totals, category_totals, _, _ = self._collect_daily_usage(
            db, profile_id
        )
        today_categories = sorted(
            (
                (category, milliseconds)
                for (usage_date, category), milliseconds in category_totals.items()
                if usage_date == today
            ),
            key=lambda item: (-item[1], item[0]),
        )
        today_total = daily_totals.get(today, 0)
        yesterday_total = daily_totals.get(today - timedelta(days=1), 0)
        weekly_total = sum(daily_totals.get(day, 0) for day in week_dates)

        return DashboardAnalyticsResponse(
            today_total_minutes=completed_minutes(today_total),
            category_breakdown=[
                CategoryBreakdownItem(
                    name=category,
                    minutes=completed_minutes(milliseconds),
                    duration_milliseconds=milliseconds,
                )
                for category, milliseconds in today_categories
            ],
            weekly_usage_hours=[
                self._milliseconds_to_hours(daily_totals.get(day, 0))
                for day in week_dates
            ],
            weekly_total_minutes=completed_minutes(weekly_total),
            delta_from_yesterday_percent=self._calculate_delta_percent(
                current_total=today_total,
                previous_total=yesterday_total,
            ),
        )

    def get_trends(self, db: Session, profile_id: str) -> TrendsAnalyticsResponse:
        effective_timezone = self._get_effective_timezone(db, profile_id)
        timezone_value = ZoneInfo(effective_timezone)
        today = self._today_in_timezone(effective_timezone)
        week_dates = self._build_day_range(today, 7)
        daily_totals, _, app_totals, app_names = self._collect_daily_usage(
            db, profile_id
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
            profile_id,
            range_start,
            range_end,
        ):
            clipped_start = max(ensure_utc(event.started_at), range_start)
            clipped_end = min(ensure_utc(event.ended_at), range_end)
            for hour_index, milliseconds in split_milliseconds_by_local_hour(
                clipped_start,
                clipped_end,
                effective_timezone,
            ):
                hourly_totals[hour_index] += milliseconds

        top_app_totals: dict[str, int] = defaultdict(int)
        for (usage_date, app_id), milliseconds in app_totals.items():
            if week_dates[0] <= usage_date <= week_dates[-1]:
                top_app_totals[app_id] += milliseconds
        top_apps = sorted(
            top_app_totals.items(),
            key=lambda item: (-item[1], app_names[item[0]]),
        )[:5]

        hourly_minutes = [
            completed_minutes(milliseconds) for milliseconds in hourly_totals
        ]
        weekly_total = sum(daily_totals.get(day, 0) for day in week_dates)

        return TrendsAnalyticsResponse(
            hourly_usage=[
                HourlyUsagePoint(hour=self._format_hour_label(hour), minutes=minutes)
                for hour, minutes in enumerate(hourly_minutes)
            ],
            weekly_usage=[
                WeeklyUsagePoint(
                    day=day.strftime("%a"),
                    hours=self._milliseconds_to_hours(daily_totals.get(day, 0)),
                )
                for day in week_dates
            ],
            weekly_total_minutes=completed_minutes(weekly_total),
            top_apps=[
                TopAppUsagePoint(
                    app_id=app_id,
                    app_name=app_names[app_id],
                    minutes=completed_minutes(milliseconds),
                )
                for app_id, milliseconds in top_apps
            ],
            peak_usage_window=self._build_peak_usage_window(hourly_totals),
        )

    def get_weekly_summary(
        self, db: Session, profile_id: str
    ) -> WeeklySummaryResponse:
        effective_timezone = self._get_effective_timezone(db, profile_id)
        today = self._today_in_timezone(effective_timezone)
        current_week_dates = self._build_day_range(today, 7)
        previous_week_end = current_week_dates[0] - timedelta(days=1)
        previous_week_dates = self._build_day_range(previous_week_end, 7)
        daily_totals, _, _, _ = self._collect_daily_usage(db, profile_id)
        current_totals = {
            day: daily_totals.get(day, 0) for day in current_week_dates
        }
        previous_totals = {
            day: daily_totals.get(day, 0) for day in previous_week_dates
        }
        preferences = self.preferences_repository.get_by_profile_id(db, profile_id)
        daily_limit = preferences.default_daily_limit_minutes if preferences is not None else 0
        daily_limit_milliseconds = daily_limit * MILLISECONDS_PER_MINUTE
        current_total_milliseconds = sum(
            current_totals.get(day, 0) for day in current_week_dates
        )
        previous_total_milliseconds = sum(
            previous_totals.get(day, 0) for day in previous_week_dates
        )
        all_daily_totals = sorted(daily_totals.items())
        has_usage_history = bool(all_daily_totals)

        goals_met_days = 0
        longest_streak_days = 0
        if has_usage_history:
            goals_met_days = sum(
                1
                for day in current_week_dates
                if current_totals.get(day, 0) <= daily_limit_milliseconds
            )
            longest_streak_days = self._calculate_longest_streak(
                all_daily_totals,
                today=today,
                daily_limit=daily_limit_milliseconds,
            )

        return WeeklySummaryResponse(
            screen_time_reduction_percent=self._calculate_reduction_percent(
                current_total=current_total_milliseconds,
                previous_total=previous_total_milliseconds,
            ),
            total_week_hours=self._milliseconds_to_hours(
                current_total_milliseconds
            ),
            daily_average_hours=self._milliseconds_to_hours(
                current_total_milliseconds / 7
            ),
            goals_met_days=goals_met_days,
            longest_streak_days=longest_streak_days,
        )

    def _collect_daily_usage(
        self, db: Session, profile_id: str
    ) -> tuple[
        dict[date, int],
        dict[tuple[date, str], int],
        dict[tuple[date, str], int],
        dict[str, str],
    ]:
        daily_totals: dict[date, int] = defaultdict(int)
        category_totals: dict[tuple[date, str], int] = defaultdict(int)
        app_totals: dict[tuple[date, str], int] = defaultdict(int)
        app_names: dict[str, str] = {}

        for event in self.usage_repository.list_all_for_profile(db, profile_id):
            classification = classify_app(
                event.app_id,
                event.app_name,
                event.category,
            )
            app_names[event.app_id] = classification.display_name
            for usage_date, milliseconds in split_milliseconds_by_local_date(
                event.started_at,
                event.ended_at,
                event.timezone,
            ):
                daily_totals[usage_date] += milliseconds
                category_totals[
                    (usage_date, classification.category)
                ] += milliseconds
                app_totals[(usage_date, event.app_id)] += milliseconds

        return daily_totals, category_totals, app_totals, app_names

    def _get_effective_timezone(self, db: Session, profile_id: str) -> str:
        return self.usage_repository.get_latest_timezone(db, profile_id) or "UTC"

    def _today_in_timezone(self, timezone_name: str) -> date:
        return current_utc_now().astimezone(ZoneInfo(timezone_name)).date()

    def _build_day_range(self, end_day: date, days: int) -> list[date]:
        start_day = end_day - timedelta(days=days - 1)
        return [start_day + timedelta(days=offset) for offset in range(days)]

    def _milliseconds_to_hours(self, milliseconds: float) -> float:
        return round(milliseconds / 3_600_000, 1)

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
        totals_by_day = {
            usage_date: total_milliseconds
            for usage_date, total_milliseconds in all_daily_totals
        }
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
