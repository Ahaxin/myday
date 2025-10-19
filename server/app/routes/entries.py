"""Entry management endpoints."""
from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel
from sqlmodel import select

from ..database import session_scope
from ..models import Entry, EntryStatus

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


@router.post("", response_model=EntryCreateResponse, status_code=201)
def create_entry(payload: EntryCreateRequest) -> EntryCreateResponse:
    """Create an entry and issue a placeholder signed upload URL."""
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

    upload_url = f"https://uploads.example.com/entries/{entry.id}.m4a"
    return EntryCreateResponse(entry_id=entry.id, upload_url=upload_url)


@router.get("", response_model=List[EntryRead])
def list_entries(since: Optional[datetime] = Query(default=None)) -> List[EntryRead]:
    """List entries optionally filtered by creation timestamp."""
    with session_scope() as session:
        statement = select(Entry)
        if since is not None:
            statement = statement.where(Entry.created_at >= since)
        statement = statement.order_by(Entry.created_at.desc())
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
            )
            for row in results
        ]


@router.get("/{entry_id}", response_model=EntryRead)
def get_entry(entry_id: int) -> EntryRead:
    """Retrieve a single entry by identifier."""
    with session_scope() as session:
        entry = session.get(Entry, entry_id)
        if entry is None:
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
def update_entry(entry_id: int, payload: EntryUpdateRequest) -> EntryRead:
    """Update mutable entry fields used by background workers."""

    updates = payload.dict(exclude_unset=True)
    if not updates:
        raise HTTPException(status_code=400, detail="No fields provided for update")

    if "status" in updates and updates["status"] not in {
        EntryStatus.UPLOADED,
        EntryStatus.TRANSCRIBED,
        EntryStatus.FAILED,
    }:
        raise HTTPException(status_code=400, detail="Invalid status value")

    with session_scope() as session:
        entry = session.get(Entry, entry_id)
        if entry is None:
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
        )
