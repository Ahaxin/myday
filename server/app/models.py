"""Database models for the My Day API."""
from datetime import datetime
from typing import Optional

from sqlmodel import Field, SQLModel


class User(SQLModel, table=True):
    """A registered My Day user."""

    id: Optional[int] = Field(default=None, primary_key=True)
    email: str = Field(index=True, unique=True)
    apple_sub: Optional[str] = Field(default=None, index=True, unique=True)
    google_sub: Optional[str] = Field(default=None, index=True, unique=True)
    created_at: datetime = Field(default_factory=datetime.utcnow, nullable=False)


class EntryStatus:
    """Allowed status values for an entry."""

    UPLOADED = "uploaded"
    PROCESSING = "processing"
    TRANSCRIBED = "transcribed"
    FAILED = "failed"


class Entry(SQLModel, table=True):
    """A single audio diary entry."""

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="user.id")
    created_at: datetime = Field(default_factory=datetime.utcnow, nullable=False)
    duration_s: int = Field(default=0, nullable=False)
    status: str = Field(default=EntryStatus.UPLOADED, nullable=False)
    audio_url: Optional[str] = Field(default=None)
    size_bytes: Optional[int] = Field(default=None)
    language: Optional[str] = Field(default=None)
    transcript_raw: Optional[str] = Field(default=None)
    transcript_clean: Optional[str] = Field(default=None)
    failure_reason: Optional[str] = Field(default=None)
    idempotency_key: Optional[str] = Field(default=None, index=True)


class ExportStatus:
    """Possible states of an export request."""

    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETE = "complete"
    FAILED = "failed"


class ExportRequest(SQLModel, table=True):
    """A request to export a range of entries."""

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="user.id")
    date_from: datetime = Field(nullable=False)
    date_to: datetime = Field(nullable=False)
    status: str = Field(default=ExportStatus.PENDING, nullable=False)
    result_url: Optional[str] = Field(default=None)
    created_at: datetime = Field(default_factory=datetime.utcnow, nullable=False)
