"""Main FastAPI application"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from .config import settings
from .db.database import init_db


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan context manager for startup/shutdown events"""
    # Startup
    print("🚀 Starting AI Calendar Backend...")
    await init_db()
    print("✅ Database initialized")

    yield

    # Shutdown
    print("👋 Shutting down...")


# Create FastAPI app
app = FastAPI(
    title="AI Calendar Backend",
    description="Multi-agent AI system for intelligent calendar and task management",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    lifespan=lifespan,
)

# CORS middleware for iOS app
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "version": "1.0.0",
        "features": {
            "agent_system": settings.enable_agent_system,
            "vector_memory": settings.enable_vector_memory,
            "smart_routing": settings.enable_smart_routing,
        },
    }


# Root endpoint
@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "AI Calendar Backend API",
        "version": "1.0.0",
        "docs": "/api/docs",
    }


# Include routers
from .api import auth, sync

app.include_router(auth.router, prefix="/api/v1/auth", tags=["Authentication"])
app.include_router(sync.router, prefix="/api/v1/sync", tags=["Sync"])

# AI router will be added in Week 9+ when agent system is ready
# from .api import ai
# app.include_router(ai.router, prefix="/api/v1/ai", tags=["AI"])
