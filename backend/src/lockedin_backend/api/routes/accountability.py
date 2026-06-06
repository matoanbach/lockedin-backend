from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from lockedin_backend.core.errors import ConflictError, NotFoundError
from lockedin_backend.db.session import get_db
from lockedin_backend.schemas.accountability import (
    AccountabilityContactCreate,
    AccountabilityContactResponse,
)
from lockedin_backend.services.accountability_service import accountability_service


router = APIRouter(prefix="/accountability/contacts", tags=["accountability"])


@router.get("", response_model=list[AccountabilityContactResponse])
def list_contacts(db: Session = Depends(get_db)) -> list[AccountabilityContactResponse]:
    return accountability_service.list_contacts(db)


@router.post(
    "", response_model=AccountabilityContactResponse, status_code=status.HTTP_201_CREATED
)
def create_contact(
    payload: AccountabilityContactCreate, db: Session = Depends(get_db)
) -> AccountabilityContactResponse:
    try:
        return accountability_service.create_contact(db, payload)
    except ConflictError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc


@router.delete("/{contact_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_contact(contact_id: str, db: Session = Depends(get_db)) -> Response:
    try:
        accountability_service.delete_contact(db, contact_id)
    except NotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)
