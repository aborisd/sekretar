-- Initialize database with pgvector extension
-- This script runs automatically when PostgreSQL container starts

-- Install pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create indexes will be handled by SQLAlchemy, but we can add vector-specific ones here

COMMENT ON EXTENSION vector IS 'pgvector extension for vector similarity search';

-- Note: Tables will be created by SQLAlchemy (FastAPI startup)
-- This file is just for extensions and initial setup

GRANT ALL PRIVILEGES ON DATABASE ai_calendar TO postgres;
