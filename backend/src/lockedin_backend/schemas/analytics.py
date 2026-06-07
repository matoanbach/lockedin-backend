from pydantic import Field

from lockedin_backend.core.serialization import APIModel


class CategoryBreakdownItem(APIModel):
    name: str
    minutes: int


class HourlyUsagePoint(APIModel):
    hour: str
    minutes: int


class WeeklyUsagePoint(APIModel):
    day: str
    hours: float


class TopAppUsagePoint(APIModel):
    app_id: str
    app_name: str
    minutes: int


class DashboardAnalyticsResponse(APIModel):
    today_total_minutes: int
    category_breakdown: list[CategoryBreakdownItem] = Field(default_factory=list)
    weekly_usage_hours: list[float] = Field(default_factory=list)
    delta_from_yesterday_percent: int


class TrendsAnalyticsResponse(APIModel):
    hourly_usage: list[HourlyUsagePoint] = Field(default_factory=list)
    weekly_usage: list[WeeklyUsagePoint] = Field(default_factory=list)
    top_apps: list[TopAppUsagePoint] = Field(default_factory=list)
    peak_usage_window: str


class WeeklySummaryResponse(APIModel):
    screen_time_reduction_percent: int
    total_week_hours: float
    daily_average_hours: float
    goals_met_days: int
    longest_streak_days: int
