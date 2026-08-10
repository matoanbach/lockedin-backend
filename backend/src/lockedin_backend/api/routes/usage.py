from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from lockedin_backend.api.dependencies.principal import (
    get_current_principal,
    get_operator_principal,
)
from lockedin_backend.core.principal import CurrentPrincipal, OperatorPrincipal
from lockedin_backend.db.session import get_db
from lockedin_backend.schemas.usage import (
    UsageAggregateRebuildResponse,
    UsageIngestionRequest,
    UsageIngestionResponse,
)
from lockedin_backend.services.usage_service import usage_service


router = APIRouter(prefix="/usage", tags=["usage"])
operator_router = APIRouter(prefix="/usage", tags=["usage-operations"])


@router.post("/events", response_model=UsageIngestionResponse)
def ingest_usage_events(
    payload: UsageIngestionRequest,
    principal: CurrentPrincipal = Depends(get_current_principal),
    db: Session = Depends(get_db),
) -> UsageIngestionResponse:
    return usage_service.ingest_events(db, principal.profile_id, payload)


@operator_router.post("/aggregates/rebuild", response_model=UsageAggregateRebuildResponse)
def rebuild_usage_aggregates(
    operator: OperatorPrincipal = Depends(get_operator_principal),
    db: Session = Depends(get_db),
) -> UsageAggregateRebuildResponse:
    """Recalculate derived aggregates without deleting accepted raw usage events."""
    return usage_service.rebuild_aggregates(db, operator.profile_id)
