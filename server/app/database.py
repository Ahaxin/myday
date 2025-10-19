"""Database utilities for the My Day API."""
from contextlib import contextmanager
from typing import Iterator

from sqlmodel import Session, SQLModel, create_engine

from . import config


engine = create_engine(config.DATABASE_URL, echo=False, future=True)


def init_db() -> None:
    """Initialize database.

    For SQLite (tests/dev), create tables automatically.
    For other engines (e.g., Postgres), rely on Alembic migrations.
    """
    if config.DATABASE_URL.startswith("sqlite"):
        SQLModel.metadata.create_all(engine)


@contextmanager
def session_scope() -> Iterator[Session]:
    """Provide a transactional scope for database operations."""
    with Session(engine) as session:
        yield session
