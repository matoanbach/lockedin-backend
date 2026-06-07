from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from lockedin_backend.core.errors import ConflictError, NotFoundError
from lockedin_backend.db.session import get_db
from lockedin_backend.schemas.rules import RuleCreate, RuleResponse, RuleUpdate
from lockedin_backend.schemas.rule_status import RuleStatusResponse
from lockedin_backend.services.rule_status_service import rule_status_service
from lockedin_backend.services.rules_service import rules_service


router = APIRouter(prefix="/rules", tags=["rules"])


@router.get("", response_model=list[RuleResponse])
def list_rules(db: Session = Depends(get_db)) -> list[RuleResponse]:
    return rules_service.list_rules(db)


@router.get("/status", response_model=list[RuleStatusResponse])
def list_rule_statuses(db: Session = Depends(get_db)) -> list[RuleStatusResponse]:
    return rule_status_service.list_rule_statuses(db)


@router.post("", response_model=RuleResponse, status_code=status.HTTP_201_CREATED)
def create_rule(payload: RuleCreate, db: Session = Depends(get_db)) -> RuleResponse:
    try:
        return rules_service.create_rule(db, payload)
    except ConflictError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc


@router.patch("/{rule_id}", response_model=RuleResponse)
def update_rule(
    rule_id: str, payload: RuleUpdate, db: Session = Depends(get_db)
) -> RuleResponse:
    try:
        return rules_service.update_rule(db, rule_id, payload)
    except NotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


@router.delete("/{rule_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_rule(rule_id: str, db: Session = Depends(get_db)) -> Response:
    try:
        rules_service.delete_rule(db, rule_id)
    except NotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)
