"""Authentication endpoints."""
from datetime import datetime, timezone
from typing import Dict

from fastapi import APIRouter, HTTPException
from jose import jwt
from pydantic import BaseModel, EmailStr
from sqlmodel import select

from .. import config
from ..database import session_scope
from ..models import User

router = APIRouter()


class EmailAuthRequest(BaseModel):
    """Payload for email/password style authentication."""

    email: EmailStr


class TokenResponse(BaseModel):
    """Response containing access token metadata."""

    access_token: str
    token_type: str = "bearer"
    expires_at: datetime
    user_id: int


class TokenPayload(BaseModel):
    """Payload included in generated JWTs."""

    sub: str
    email: EmailStr
    exp: int


@router.post("/email", response_model=TokenResponse)
def authenticate_email(payload: EmailAuthRequest) -> TokenResponse:
    """Authenticate a user via email and mint a short-lived JWT."""
    with session_scope() as session:
        existing_user = session.exec(select(User).where(User.email == payload.email)).first()
        if existing_user is None:
            existing_user = User(email=payload.email)
            session.add(existing_user)
            session.commit()
            session.refresh(existing_user)

    expires_at = datetime.now(timezone.utc) + config.access_token_expires_delta()
    exp_ts = int(expires_at.timestamp())
    token = _generate_token({"sub": str(existing_user.id), "email": existing_user.email, "exp": exp_ts})
    # For response, provide naive ISO string for simplicity
    return TokenResponse(access_token=token, expires_at=expires_at.replace(tzinfo=None), user_id=existing_user.id)


def _generate_token(claims: Dict[str, str]) -> str:
    """Generate a signed JWT for the provided claims."""
    try:
        return jwt.encode(claims, config.SECRET_KEY, algorithm=config.ALGORITHM)
    except Exception as exc:  # pragma: no cover - defensive
        raise HTTPException(status_code=500, detail="Failed to generate token") from exc
