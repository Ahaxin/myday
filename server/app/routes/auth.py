"""Authentication endpoints."""
from datetime import datetime, timedelta
from typing import Dict

from fastapi import APIRouter, HTTPException
from jose import jwt
from pydantic import BaseModel, EmailStr
from sqlmodel import select

from ..database import session_scope
from ..models import User

SECRET_KEY = "myday-secret"
ALGORITHM = "HS256"
TOKEN_EXPIRY_MINUTES = 60

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

    expires_at = datetime.utcnow() + timedelta(minutes=TOKEN_EXPIRY_MINUTES)
    token = _generate_token({"sub": str(existing_user.id), "email": existing_user.email, "exp": int(expires_at.timestamp())})
    return TokenResponse(access_token=token, expires_at=expires_at, user_id=existing_user.id)


def _generate_token(claims: Dict[str, str]) -> str:
    """Generate a signed JWT for the provided claims."""
    try:
        return jwt.encode(claims, SECRET_KEY, algorithm=ALGORITHM)
    except Exception as exc:  # pragma: no cover - defensive
        raise HTTPException(status_code=500, detail="Failed to generate token") from exc
