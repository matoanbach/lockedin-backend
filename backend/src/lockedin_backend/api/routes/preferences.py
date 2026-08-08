from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from lockedin_backend.api.dependencies.principal import get_current_principal
from lockedin_backend.core.principal import CurrentPrincipal
from lockedin_backend.db.session import get_db
from lockedin_backend.schemas.preferences import PreferencesResponse, PreferencesUpdate
from lockedin_backend.services.preferences_service import preferences_service


router = APIRouter(prefix="/me", tags=["preferences"])


@router.get("/preferences", response_model=PreferencesResponse)
def get_preferences(
    principal: CurrentPrincipal = Depends(get_current_principal),
    db: Session = Depends(get_db),
) -> PreferencesResponse:
    return preferences_service.get_preferences(db, principal.profile_id)


@router.put("/preferences", response_model=PreferencesResponse)
def update_preferences(
    payload: PreferencesUpdate,
    principal: CurrentPrincipal = Depends(get_current_principal),
    db: Session = Depends(get_db),
) -> PreferencesResponse:
    return preferences_service.update_preferences(db, principal.profile_id, payload)
