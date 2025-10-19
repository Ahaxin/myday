"""Database utilities for the My Day API."""
from contextlib import contextmanager
from typing import Iterator

from sqlmodel import Session, SQLModel, create_engine


DATABASE_URL = "sqlite:///./myday.db"
engine = create_engine(DATABASE_URL, echo=False, future=True)


def init_db() -> None:
    """Create database tables."""
    SQLModel.metadata.create_all(engine)


@contextmanager
def session_scope() -> Iterator[Session]:
    """Provide a transactional scope for database operations."""
    with Session(engine) as session:
        yield session
