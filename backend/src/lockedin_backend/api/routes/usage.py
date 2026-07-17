from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from lockedin_backend.db.session import get_db
from lockedin_backend.schemas.usage import (
    UsageAggregateRebuildResponse,
    UsageIngestionRequest,
    UsageIngestionResponse,
)
from lockedin_backend.services.usage_service import UsageOverlapError, usage_service


router = APIRouter(prefix="/usage", tags=["usage"])


@router.post("/events", response_model=UsageIngestionResponse)
def ingest_usage_events(
    payload: UsageIngestionRequest,
    db: Session = Depends(get_db),
) -> UsageIngestionResponse:
    try:
        return usage_service.ingest_events(db, payload)
    except UsageOverlapError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc


@router.post("/aggregates/rebuild", response_model=UsageAggregateRebuildResponse)
def rebuild_usage_aggregates(
    db: Session = Depends(get_db),
) -> UsageAggregateRebuildResponse:
    """Recalculate derived aggregates without deleting accepted raw usage events."""
    return usage_service.rebuild_aggregates(db)
