"""Configuration settings for the backend"""

from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    """Application settings"""

    # Database
    database_url: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/ai_calendar"
    redis_url: str = "redis://localhost:6379"

    # AI APIs
    anthropic_api_key: Optional[str] = None
    openai_api_key: Optional[str] = None
    google_api_key: Optional[str] = None  # For Gemini

    # Authentication
    jwt_secret: str = "your-secret-key-change-in-production"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24 * 7  # 1 week

    # Feature flags
    enable_agent_system: bool = False  # Enable in Phase 2 (Week 9-16)
    enable_vector_memory: bool = True  # Already done in Week 1-2
    enable_smart_routing: bool = True  # Already done in Week 3-4

    # CORS
    cors_origins: list[str] = ["*"]  # Restrict in production

    # Rate limiting
    rate_limit_per_minute: int = 60  # Requests per minute per user

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


# Global settings instance
settings = Settings()
