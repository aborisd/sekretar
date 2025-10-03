"""User model"""

from sqlalchemy import Column, String, DateTime, Text
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.sql import func
import uuid

from ..db.database import Base


class User(Base):
    """User model for authentication and profile"""

    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String(255), unique=True, nullable=False, index=True)
    apple_id = Column(String(255), unique=True, nullable=True, index=True)  # For Apple Sign In

    # Subscription tier
    tier = Column(String(20), default="free", nullable=False)  # free, basic, pro, premium, teams

    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    last_active_at = Column(DateTime(timezone=True), nullable=True)

    # User preferences (JSON)
    preferences = Column(JSONB, default=dict, nullable=False)

    # Hashed password (for email/password auth, optional if using Apple Sign In only)
    hashed_password = Column(Text, nullable=True)

    def __repr__(self) -> str:
        return f"<User(id={self.id}, email={self.email}, tier={self.tier})>"
