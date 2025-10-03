"""Task model"""

from sqlalchemy import Column, String, Text, DateTime, Integer, Boolean, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
import uuid

from ..db.database import Base


class Task(Base):
    """Task model - server-side copy for sync"""

    __tablename__ = "tasks"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

    # Task data
    title = Column(Text, nullable=False)
    notes = Column(Text, nullable=True)
    due_date = Column(DateTime(timezone=True), nullable=True)
    priority = Column(String(10), nullable=True)  # low, medium, high
    project_id = Column(UUID(as_uuid=True), nullable=True)  # For future project support

    # Status
    completed_at = Column(DateTime(timezone=True), nullable=True)
    is_deleted = Column(Boolean, default=False, nullable=False)

    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    modified_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    # Conflict resolution
    version = Column(Integer, default=1, nullable=False)

    def __repr__(self) -> str:
        return f"<Task(id={self.id}, title={self.title[:30]}, user_id={self.user_id})>"
