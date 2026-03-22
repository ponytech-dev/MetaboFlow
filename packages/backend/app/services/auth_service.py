"""Auth service: password hashing, JWT creation/verification, invite code generation."""

from __future__ import annotations

import secrets
import string
from datetime import datetime, timedelta, UTC
from typing import Optional

import bcrypt
from jose import JWTError, jwt
from sqlalchemy.orm import Session

from app.config import settings
from app.db.models import InviteCode, User

ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30
REFRESH_TOKEN_EXPIRE_DAYS = 7


# ---------------------------------------------------------------------------
# Password helpers (using bcrypt directly — passlib incompatible with bcrypt 5.x)
# ---------------------------------------------------------------------------

def hash_password(plain: str) -> str:
    return bcrypt.hashpw(plain.encode(), bcrypt.gensalt()).decode()


def verify_password(plain: str, hashed: str) -> bool:
    return bcrypt.checkpw(plain.encode(), hashed.encode())


# ---------------------------------------------------------------------------
# JWT helpers
# ---------------------------------------------------------------------------

def create_access_token(user_id: str) -> str:
    expire = datetime.now(UTC) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {"sub": user_id, "type": "access", "exp": expire}
    return jwt.encode(payload, settings.secret_key, algorithm=ALGORITHM)


def create_refresh_token(user_id: str) -> str:
    expire = datetime.now(UTC) + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    payload = {"sub": user_id, "type": "refresh", "exp": expire}
    return jwt.encode(payload, settings.secret_key, algorithm=ALGORITHM)


def verify_token(token: str, expected_type: str) -> Optional[str]:
    """Decode a JWT and return the user_id, or None on failure."""
    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=[ALGORITHM])
        if payload.get("type") != expected_type:
            return None
        return payload.get("sub")
    except JWTError:
        return None


# ---------------------------------------------------------------------------
# Registration & authentication
# ---------------------------------------------------------------------------

def register(db: Session, email: str, password: str, invite_code: str) -> User:
    """Register a new user using a valid invite code.

    Raises ValueError on any validation failure.
    """
    # Check invite code
    code_obj: Optional[InviteCode] = (
        db.query(InviteCode)
        .filter(InviteCode.code == invite_code, InviteCode.used_by.is_(None))
        .first()
    )
    if code_obj is None:
        raise ValueError("Invalid or already-used invite code")
    if code_obj.expires_at < datetime.now(UTC):
        raise ValueError("Invite code has expired")

    # Check email uniqueness
    if db.query(User).filter(User.email == email).first():
        raise ValueError("Email already registered")

    user = User(email=email, password_hash=hash_password(password))
    db.add(user)
    db.flush()  # get user.id before committing

    # Mark invite code as used
    code_obj.used_by = user.id
    db.commit()
    db.refresh(user)
    return user


def authenticate(db: Session, email: str, password: str) -> Optional[User]:
    """Return the User if credentials are valid, else None."""
    user: Optional[User] = db.query(User).filter(User.email == email).first()
    if user is None or not verify_password(password, user.password_hash):
        return None
    return user


# ---------------------------------------------------------------------------
# Invite code generation
# ---------------------------------------------------------------------------

_CODE_CHARS = string.ascii_letters + string.digits


def generate_invite_code(db: Session, expires_in_days: int = 7) -> InviteCode:
    """Generate and persist a new invite code."""
    code = "".join(secrets.choice(_CODE_CHARS) for _ in range(24))
    expires_at = datetime.now(UTC) + timedelta(days=expires_in_days)
    invite = InviteCode(code=code, expires_at=expires_at)
    db.add(invite)
    db.commit()
    db.refresh(invite)
    return invite
