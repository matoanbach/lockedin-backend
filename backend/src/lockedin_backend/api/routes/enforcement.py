from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from lockedin_backend.api.dependencies.principal import get_current_principal
from lockedin_backend.core.principal import CurrentPrincipal
from lockedin_backend.core.errors import NotFoundError
from lockedin_backend.db.session import get_db
from lockedin_backend.schemas.enforcement import (
    EnforcementEventCreate,
    EnforcementEventResponse,
)
from lockedin_backend.services.enforcement_service import enforcement_service


router = APIRouter(prefix="/enforcement", tags=["enforcement"])


@router.post(
    "/events",
    response_model=EnforcementEventResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_enforcement_event(
    payload: EnforcementEventCreate,
    principal: CurrentPrincipal = Depends(get_current_principal),
    db: Session = Depends(get_db),
) -> EnforcementEventResponse:
    try:
        return enforcement_service.create_event(db, principal.profile_id, payload)
    except NotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
