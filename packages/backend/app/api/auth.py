"""Auth API endpoints: register, login, refresh, invite-codes, me."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session

from app.db.base import get_db
from app.db.models import User
from app.middleware.auth import get_admin_user, get_current_user
from app.services import auth_service

router = APIRouter(prefix="/auth", tags=["auth"])

# ---------------------------------------------------------------------------
# Request / Response schemas
# ---------------------------------------------------------------------------


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str
    invite_code: str


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str


class RegisterTokenResponse(TokenResponse):
    refresh_token: str


class UserOut(BaseModel):
    id: str
    email: str
    is_admin: bool


class InviteCodeOut(BaseModel):
    id: str
    code: str
    expires_at: str


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.post("/register", response_model=RegisterTokenResponse, status_code=status.HTTP_201_CREATED)
async def register(body: RegisterRequest, db: Session = Depends(get_db)) -> RegisterTokenResponse:
    try:
        user = auth_service.register(db, body.email, body.password, body.invite_code)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))
    access = auth_service.create_access_token(user.id)
    refresh = auth_service.create_refresh_token(user.id)
    return RegisterTokenResponse(
        access_token=access,
        refresh_token=refresh,
        user_id=user.id,
    )


@router.post("/login", response_model=TokenResponse)
async def login(body: LoginRequest, response: Response, db: Session = Depends(get_db)) -> TokenResponse:
    user = auth_service.authenticate(db, body.email, body.password)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )
    access = auth_service.create_access_token(user.id)
    refresh = auth_service.create_refresh_token(user.id)
    # Set refresh token as httpOnly cookie
    response.set_cookie(
        key="refresh_token",
        value=refresh,
        httponly=True,
        samesite="lax",
        max_age=60 * 60 * 24 * 7,  # 7 days in seconds
    )
    return TokenResponse(access_token=access, user_id=user.id)


@router.post("/refresh")
async def refresh_token(request: Request, response: Response) -> dict:  # type: ignore[type-arg]
    refresh = request.cookies.get("refresh_token")
    if not refresh:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="No refresh token")
    user_id = auth_service.verify_token(refresh, "refresh")
    if user_id is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")
    access = auth_service.create_access_token(user_id)
    return {"access_token": access}


@router.post("/invite-codes", response_model=InviteCodeOut)
async def create_invite_code(
    admin: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
) -> InviteCodeOut:
    invite = auth_service.generate_invite_code(db)
    return InviteCodeOut(
        id=invite.id,
        code=invite.code,
        expires_at=invite.expires_at.isoformat(),
    )


@router.get("/me", response_model=UserOut)
async def me(current_user: User = Depends(get_current_user)) -> UserOut:
    return UserOut(id=current_user.id, email=current_user.email, is_admin=current_user.is_admin)
