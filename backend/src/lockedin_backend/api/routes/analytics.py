from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from lockedin_backend.db.session import get_db
from lockedin_backend.schemas.analytics import (
    DashboardAnalyticsResponse,
    TrendsAnalyticsResponse,
    WeeklySummaryResponse,
)
from lockedin_backend.services.analytics_service import analytics_service


router = APIRouter(prefix="/analytics", tags=["analytics"])


@router.get("/dashboard", response_model=DashboardAnalyticsResponse)
def get_dashboard_analytics(db: Session = Depends(get_db)) -> DashboardAnalyticsResponse:
    return analytics_service.get_dashboard(db)


@router.get("/trends", response_model=TrendsAnalyticsResponse)
def get_trends_analytics(db: Session = Depends(get_db)) -> TrendsAnalyticsResponse:
    return analytics_service.get_trends(db)


@router.get("/weekly-summary", response_model=WeeklySummaryResponse)
def get_weekly_summary_analytics(
    db: Session = Depends(get_db),
) -> WeeklySummaryResponse:
    return analytics_service.get_weekly_summary(db)
