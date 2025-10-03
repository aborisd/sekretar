"""Memory model for RAG (vector search)"""

from sqlalchemy import Column, Text, DateTime, String, BigInteger, ForeignKey, Index
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.sql import func
from pgvector.sqlalchemy import Vector

from ..db.database import Base


class Memory(Base):
    """Memory model for vector search and RAG"""

    __tablename__ = "memories"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

    # Content
    content = Column(Text, nullable=False)
    embedding = Column(Vector(768), nullable=True)  # 768-dimensional embedding

    # Memory type
    memory_type = Column(
        String(50),
        nullable=False,
        index=True
    )  # interaction, task, event, insight, preference, context

    # Metadata (JSON)
    metadata = Column(JSONB, default=dict, nullable=False)

    # Timestamp
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    # Composite index for efficient queries
    __table_args__ = (
        Index("idx_memories_user_type", "user_id", "memory_type", "created_at"),
    )

    def __repr__(self) -> str:
        return f"<Memory(id={self.id}, type={self.memory_type}, user_id={self.user_id})>"
