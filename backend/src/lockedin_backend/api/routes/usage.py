from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from lockedin_backend.db.session import get_db
from lockedin_backend.schemas.usage import UsageIngestionRequest, UsageIngestionResponse
from lockedin_backend.services.usage_service import usage_service


router = APIRouter(prefix="/usage", tags=["usage"])


@router.post("/events", response_model=UsageIngestionResponse)
def ingest_usage_events(
    payload: UsageIngestionRequest,
    db: Session = Depends(get_db),
) -> UsageIngestionResponse:
    return usage_service.ingest_events(db, payload)
