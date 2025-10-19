"""Export request endpoints."""
from datetime import datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlmodel import select

from ..database import session_scope
from ..models import ExportRequest, ExportStatus, User
from .. import config
from ..security import get_current_user

router = APIRouter()


class ExportCreateRequest(BaseModel):
    """Payload for requesting an export."""

    user_id: int
    date_from: datetime
    date_to: datetime
    email: str


class ExportRead(BaseModel):
    """Serialized representation of an export request."""

    id: int
    user_id: int
    date_from: datetime
    date_to: datetime
    status: str
    result_url: str | None
    created_at: datetime


@router.post("", response_model=ExportRead, status_code=201)
def create_export(
    payload: ExportCreateRequest,
    current_user: User = Depends(get_current_user),
) -> ExportRead:
    """Create an export request and generate archive synchronously (dev) or enqueue."""
    if payload.date_from > payload.date_to:
        raise HTTPException(status_code=400, detail="date_from must be before date_to")
    if payload.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="user_id mismatch")

    with session_scope() as session:
        export = ExportRequest(
            user_id=payload.user_id,
            date_from=payload.date_from,
            date_to=payload.date_to,
            status=ExportStatus.PROCESSING,
            result_url=None,
        )
        session.add(export)
        session.commit()
        session.refresh(export)

    if config.EXPORT_SYNC:
        from ..tasks import generate_export

        generate_export(export.id)
        with session_scope() as session:
            export = session.get(ExportRequest, export.id)
    else:  # pragma: no cover - runtime path
        try:
            from ..tasks import generate_export as generate_export_task

            generate_export_task.delay(export.id)
        except Exception:
            pass

    return ExportRead(
        id=export.id,
        user_id=export.user_id,
        date_from=export.date_from,
        date_to=export.date_to,
        status=export.status,
        result_url=export.result_url,
        created_at=export.created_at,
    )


@router.get("", response_model=List[ExportRead])
def list_exports(user_id: int, current_user: User = Depends(get_current_user)) -> List[ExportRead]:
    """List export requests for a user."""
    if user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="user_id mismatch")
    with session_scope() as session:
        exports = session.exec(select(ExportRequest).where(ExportRequest.user_id == user_id)).all()
        return [
            ExportRead(
                id=item.id,
                user_id=item.user_id,
                date_from=item.date_from,
                date_to=item.date_to,
                status=item.status,
                result_url=item.result_url,
                created_at=item.created_at,
            )
            for item in exports
        ]


@router.get("/{export_id}", response_model=ExportRead)
def get_export(export_id: int, current_user: User = Depends(get_current_user)) -> ExportRead:
    """Retrieve a single export request."""
    with session_scope() as session:
        export = session.get(ExportRequest, export_id)
        if export is None or export.user_id != current_user.id:
            raise HTTPException(status_code=404, detail="Export not found")
        return ExportRead(
            id=export.id,
            user_id=export.user_id,
            date_from=export.date_from,
            date_to=export.date_to,
            status=export.status,
            result_url=export.result_url,
            created_at=export.created_at,
        )
