"""Authentication endpoints"""

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr
from sqlalchemy.ext.asyncio import AsyncSession

from ..db.database import get_db
from ..services.auth_service import (
    verify_password,
    create_access_token,
    get_user_by_email,
    get_user_by_apple_id,
    create_user,
)

router = APIRouter()


# Request/Response models
class UserRegister(BaseModel):
    email: EmailStr
    password: str


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class AppleSignIn(BaseModel):
    apple_id: str
    email: EmailStr
    full_name: str | None = None


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    email: str
    tier: str


@router.post("/register", response_model=TokenResponse)
async def register(data: UserRegister, db: AsyncSession = Depends(get_db)):
    """Register new user with email/password"""

    # Check if user already exists
    existing_user = await get_user_by_email(db, data.email)
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Email already registered"
        )

    # Create user
    user = await create_user(db, email=data.email, password=data.password)

    # Generate JWT token
    access_token = create_access_token(data={"sub": str(user.id)})

    return TokenResponse(
        access_token=access_token,
        user_id=str(user.id),
        email=user.email,
        tier=user.tier,
    )


@router.post("/login", response_model=TokenResponse)
async def login(data: UserLogin, db: AsyncSession = Depends(get_db)):
    """Login with email/password"""

    # Find user
    user = await get_user_by_email(db, data.email)
    if not user or not user.hashed_password:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )

    # Verify password
    if not verify_password(data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )

    # Generate JWT token
    access_token = create_access_token(data={"sub": str(user.id)})

    return TokenResponse(
        access_token=access_token,
        user_id=str(user.id),
        email=user.email,
        tier=user.tier,
    )


@router.post("/apple", response_model=TokenResponse)
async def apple_sign_in(data: AppleSignIn, db: AsyncSession = Depends(get_db)):
    """Apple Sign In - create or login user"""

    # Check if user exists by Apple ID
    user = await get_user_by_apple_id(db, data.apple_id)

    if not user:
        # Check if user exists by email
        user = await get_user_by_email(db, data.email)

        if user:
            # Link Apple ID to existing account
            user.apple_id = data.apple_id
            await db.commit()
            await db.refresh(user)
        else:
            # Create new user
            user = await create_user(db, email=data.email, apple_id=data.apple_id)

    # Generate JWT token
    access_token = create_access_token(data={"sub": str(user.id)})

    return TokenResponse(
        access_token=access_token,
        user_id=str(user.id),
        email=user.email,
        tier=user.tier,
    )
