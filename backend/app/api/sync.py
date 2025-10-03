"""Sync endpoints for iOS app"""

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from datetime import datetime
from uuid import UUID

from ..db.database import get_db
from ..services.auth_service import get_current_user
from ..models.user import User
from ..models.task import Task

router = APIRouter()


# Request/Response models
class TaskSync(BaseModel):
    id: UUID
    title: str
    notes: str | None = None
    due_date: datetime | None = None
    priority: str | None = None
    completed_at: datetime | None = None
    is_deleted: bool = False
    version: int


class SyncPushRequest(BaseModel):
    tasks: list[TaskSync]
    last_sync_at: datetime | None = None


class SyncPullResponse(BaseModel):
    tasks: list[TaskSync]
    server_time: datetime


class SyncPushResponse(BaseModel):
    success: bool
    conflicts: list[UUID] = []
    server_time: datetime


@router.post("/push", response_model=SyncPushResponse)
async def push_changes(
    data: SyncPushRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Push changes from iOS to server"""

    conflicts: list[UUID] = []

    for task_data in data.tasks:
        # Check if task exists on server
        result = await db.execute(
            select(Task).where(and_(Task.id == task_data.id, Task.user_id == current_user.id))
        )
        existing_task = result.scalar_one_or_none()

        if existing_task:
            # Check for conflicts (server version > client version)
            if existing_task.version > task_data.version:
                conflicts.append(task_data.id)
                continue

            # Update existing task
            existing_task.title = task_data.title
            existing_task.notes = task_data.notes
            existing_task.due_date = task_data.due_date
            existing_task.priority = task_data.priority
            existing_task.completed_at = task_data.completed_at
            existing_task.is_deleted = task_data.is_deleted
            existing_task.version = task_data.version + 1
            existing_task.modified_at = datetime.utcnow()

        else:
            # Create new task
            new_task = Task(
                id=task_data.id,
                user_id=current_user.id,
                title=task_data.title,
                notes=task_data.notes,
                due_date=task_data.due_date,
                priority=task_data.priority,
                completed_at=task_data.completed_at,
                is_deleted=task_data.is_deleted,
                version=task_data.version,
            )
            db.add(new_task)

    await db.commit()

    return SyncPushResponse(
        success=True,
        conflicts=conflicts,
        server_time=datetime.utcnow(),
    )


@router.get("/pull", response_model=SyncPullResponse)
async def pull_changes(
    since: datetime | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Pull changes from server to iOS"""

    # Build query
    query = select(Task).where(Task.user_id == current_user.id)

    if since:
        # Only fetch tasks modified after 'since'
        query = query.where(Task.modified_at > since)

    # Fetch tasks
    result = await db.execute(query.order_by(Task.modified_at.desc()))
    tasks = result.scalars().all()

    # Convert to response format
    task_syncs = [
        TaskSync(
            id=task.id,
            title=task.title,
            notes=task.notes,
            due_date=task.due_date,
            priority=task.priority,
            completed_at=task.completed_at,
            is_deleted=task.is_deleted,
            version=task.version,
        )
        for task in tasks
    ]

    return SyncPullResponse(
        tasks=task_syncs,
        server_time=datetime.utcnow(),
    )


@router.get("/status")
async def sync_status(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get sync status for current user"""

    # Count tasks
    result = await db.execute(
        select(Task).where(and_(Task.user_id == current_user.id, Task.is_deleted == False))
    )
    total_tasks = len(result.scalars().all())

    # Get last modified task
    result = await db.execute(
        select(Task)
        .where(Task.user_id == current_user.id)
        .order_by(Task.modified_at.desc())
        .limit(1)
    )
    last_task = result.scalar_one_or_none()

    return {
        "user_id": str(current_user.id),
        "total_tasks": total_tasks,
        "last_modified_at": last_task.modified_at if last_task else None,
        "server_time": datetime.utcnow(),
    }
