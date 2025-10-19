"""Entry management endpoints."""
from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlmodel import select

from ..database import session_scope
from ..models import Entry, EntryStatus, User
from ..storage import generate_object_key, generate_upload_url
from .. import config
from ..security import get_current_user

router = APIRouter()


class EntryCreateRequest(BaseModel):
    """Payload used to create a new entry."""

    user_id: int
    duration_s: int
    size_bytes: Optional[int] = None
    language: Optional[str] = None


class EntryCreateResponse(BaseModel):
    """Response metadata for a new entry."""

    entry_id: int
    upload_url: str
    object_key: str


class EntryRead(BaseModel):
    """Serializable representation of an entry."""

    id: int
    user_id: int
    created_at: datetime
    duration_s: int
    status: str
    audio_url: Optional[str]
    size_bytes: Optional[int]
    language: Optional[str]
    transcript_clean: Optional[str]
    transcript_raw: Optional[str] = None
    failure_reason: Optional[str] = None


@router.post("", response_model=EntryCreateResponse, status_code=201)
def create_entry(
    payload: EntryCreateRequest,
    current_user: User = Depends(get_current_user),
) -> EntryCreateResponse:
    """Create an entry and issue a placeholder signed upload URL."""
    if payload.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="user_id mismatch")
    with session_scope() as session:
        entry = Entry(
            user_id=payload.user_id,
            duration_s=payload.duration_s,
            size_bytes=payload.size_bytes,
            language=payload.language,
            status=EntryStatus.UPLOADED,
            audio_url=None,
        )
        session.add(entry)
        session.commit()
        session.refresh(entry)

    # Generate object key and signed upload URL
    object_key = generate_object_key(user_id=payload.user_id, suffix="m4a")
    upload_url = generate_upload_url(object_key)
    return EntryCreateResponse(entry_id=entry.id, upload_url=upload_url, object_key=object_key)


class FinalizeUploadRequest(BaseModel):
    """Payload to finalize an upload for an entry."""

    object_key: str
    size_bytes: Optional[int] = None
    content_type: Optional[str] = None
    language: Optional[str] = None


@router.post("/{entry_id}/finalize", response_model=EntryRead)
def finalize_upload(
    entry_id: int,
    payload: FinalizeUploadRequest,
    current_user: User = Depends(get_current_user),
) -> EntryRead:
    """Finalize an upload by setting the entry's audio_url and optional metadata."""
    with session_scope() as session:
        entry = session.get(Entry, entry_id)
        if entry is None or entry.user_id != current_user.id:
            raise HTTPException(status_code=404, detail="Entry not found")

        from ..storage import object_public_url, object_exists

        # Optional verification that the object exists in storage
        if config.VERIFY_UPLOADS and not object_exists(payload.object_key):
            raise HTTPException(status_code=400, detail="Uploaded object not found in storage")

        entry.audio_url = object_public_url(payload.object_key)
        if payload.size_bytes is not None:
            entry.size_bytes = payload.size_bytes
        if payload.language is not None:
            entry.language = payload.language
        # Transition to processing and assign a new idempotency key
        import uuid
        entry.status = EntryStatus.PROCESSING
        idemp = uuid.uuid4().hex
        entry.idempotency_key = idemp

        session.add(entry)
        session.commit()
        session.refresh(entry)

        # Enqueue transcription in background with idempotency key
        try:  # pragma: no cover - optional runtime path
            from ..tasks import transcribe_entry

            transcribe_entry.delay(entry.id, idempotency_key=idemp)
        except Exception:
            # Swallow errors to avoid impacting API response when worker is offline
            pass

        return EntryRead(
            id=entry.id,
            user_id=entry.user_id,
            created_at=entry.created_at,
            duration_s=entry.duration_s,
            status=entry.status,
            audio_url=entry.audio_url,
            size_bytes=entry.size_bytes,
            language=entry.language,
            transcript_clean=entry.transcript_clean,
            transcript_raw=entry.transcript_raw,
            failure_reason=entry.failure_reason,
        )


class TranscribeRequest(BaseModel):
    """Request to (re)enqueue transcription for an entry."""

    idempotency_key: Optional[str] = None


@router.post("/{entry_id}/transcribe", response_model=EntryRead)
def enqueue_transcription(
    entry_id: int,
    payload: TranscribeRequest,
    current_user: User = Depends(get_current_user),
) -> EntryRead:
    with session_scope() as session:
        entry = session.get(Entry, entry_id)
        if entry is None or entry.user_id != current_user.id:
            raise HTTPException(status_code=404, detail="Entry not found")

        # Move to processing and assign/replace idempotency key
        import uuid

        entry.status = EntryStatus.PROCESSING
        key = payload.idempotency_key or uuid.uuid4().hex
        entry.idempotency_key = key
        session.add(entry)
        session.commit()
        session.refresh(entry)

        try:  # pragma: no cover - best effort
            from ..tasks import transcribe_entry

            transcribe_entry.delay(entry.id, idempotency_key=key)
        except Exception:
            pass

        return EntryRead(
            id=entry.id,
            user_id=entry.user_id,
            created_at=entry.created_at,
            duration_s=entry.duration_s,
            status=entry.status,
            audio_url=entry.audio_url,
            size_bytes=entry.size_bytes,
            language=entry.language,
            transcript_clean=entry.transcript_clean,
            transcript_raw=entry.transcript_raw,
            failure_reason=entry.failure_reason,
        )


@router.get("", response_model=List[EntryRead])
def list_entries(
    since: Optional[datetime] = Query(default=None),
    # New filters
    status_filter: Optional[str] = Query(default=None, alias="status"),
    date_from: Optional[datetime] = Query(default=None),
    date_to: Optional[datetime] = Query(default=None),
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    current_user: User = Depends(get_current_user),
) -> List[EntryRead]:
    """List entries for the current user with optional filters and pagination.

    Supported query params:
    - since: legacy filter; returns entries created at or after this timestamp.
    - status: one of uploaded|transcribed|failed.
    - date_from/date_to: inclusive range on created_at.
    - limit/offset: pagination controls.
    """
    with session_scope() as session:
        statement = select(Entry).where(Entry.user_id == current_user.id)

        if since is not None:
            statement = statement.where(Entry.created_at >= since)
        if date_from is not None:
            statement = statement.where(Entry.created_at >= date_from)
        if date_to is not None:
            statement = statement.where(Entry.created_at <= date_to)
        if status_filter is not None:
            if status_filter not in {EntryStatus.UPLOADED, EntryStatus.TRANSCRIBED, EntryStatus.FAILED}:
                raise HTTPException(status_code=400, detail="Invalid status value")
            statement = statement.where(Entry.status == status_filter)

        statement = statement.order_by(Entry.created_at.desc())
        # Apply pagination
        statement = statement.offset(offset).limit(limit)

        results = session.exec(statement).all()
        return [
            EntryRead(
                id=row.id,
                user_id=row.user_id,
                created_at=row.created_at,
                duration_s=row.duration_s,
                status=row.status,
                audio_url=row.audio_url,
                size_bytes=row.size_bytes,
                language=row.language,
                transcript_clean=row.transcript_clean,
                transcript_raw=row.transcript_raw,
                failure_reason=row.failure_reason,
            )
            for row in results
        ]


@router.get("/{entry_id}", response_model=EntryRead)
def get_entry(entry_id: int, current_user: User = Depends(get_current_user)) -> EntryRead:
    """Retrieve a single entry by identifier."""
    with session_scope() as session:
        entry = session.get(Entry, entry_id)
        if entry is None or entry.user_id != current_user.id:
            raise HTTPException(status_code=404, detail="Entry not found")
        return EntryRead(
            id=entry.id,
            user_id=entry.user_id,
            created_at=entry.created_at,
            duration_s=entry.duration_s,
            status=entry.status,
            audio_url=entry.audio_url,
            size_bytes=entry.size_bytes,
            language=entry.language,
            transcript_clean=entry.transcript_clean,
            transcript_raw=entry.transcript_raw,
            failure_reason=entry.failure_reason,
        )


class EntryUpdateRequest(BaseModel):
    """Payload used to update entry metadata once processing completes."""

    status: Optional[str] = None
    audio_url: Optional[str] = None
    size_bytes: Optional[int] = None
    language: Optional[str] = None
    transcript_raw: Optional[str] = None
    transcript_clean: Optional[str] = None


@router.patch("/{entry_id}", response_model=EntryRead)
def update_entry(
    entry_id: int,
    payload: EntryUpdateRequest,
    current_user: User = Depends(get_current_user),
) -> EntryRead:
    """Update mutable entry fields used by background workers."""

    updates = payload.dict(exclude_unset=True)
    if not updates:
        raise HTTPException(status_code=400, detail="No fields provided for update")

    if "status" in updates and updates["status"] not in {
        EntryStatus.UPLOADED,
        EntryStatus.PROCESSING,
        EntryStatus.TRANSCRIBED,
        EntryStatus.FAILED,
    }:
        raise HTTPException(status_code=400, detail="Invalid status value")

    with session_scope() as session:
        entry = session.get(Entry, entry_id)
        if entry is None or entry.user_id != current_user.id:
            raise HTTPException(status_code=404, detail="Entry not found")

        for field, value in updates.items():
            setattr(entry, field, value)

        session.add(entry)
        session.commit()
        session.refresh(entry)

        return EntryRead(
            id=entry.id,
            user_id=entry.user_id,
            created_at=entry.created_at,
            duration_s=entry.duration_s,
            status=entry.status,
            audio_url=entry.audio_url,
            size_bytes=entry.size_bytes,
            language=entry.language,
            transcript_clean=entry.transcript_clean,
            transcript_raw=entry.transcript_raw,
            failure_reason=entry.failure_reason,
        )
