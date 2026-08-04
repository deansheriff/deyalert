from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import text

from app.core.config import get_settings
from app.core.database import get_session_factory
from app.core.security import CurrentUser, get_current_user
from app.models.notification import Notification, NotificationList

router = APIRouter(prefix="/notifications", tags=["notifications"])
User = Annotated[CurrentUser, Depends(get_current_user)]


@router.get("", response_model=NotificationList)
def list_notifications(
    user: User,
    limit: int = Query(default=100, ge=1, le=200),
) -> NotificationList:
    if get_settings().use_in_memory_store:
        return NotificationList(items=[], total=0, unread=0)
    with get_session_factory()() as session:
        rows = session.execute(
            text(
                """
                SELECT id, incident_id, title, body, severity, read_at, created_at
                FROM notifications WHERE user_id = :user_id
                ORDER BY created_at DESC LIMIT :limit
                """
            ),
            {"user_id": user.id, "limit": limit},
        ).all()
        items = [Notification.model_validate(dict(row._mapping)) for row in rows]
        unread = session.execute(
            text(
                "SELECT COUNT(*) FROM notifications "
                "WHERE user_id = :user_id AND read_at IS NULL"
            ),
            {"user_id": user.id},
        ).scalar_one()
    return NotificationList(items=items, total=len(items), unread=unread)


@router.patch("/{notification_id}/read", response_model=Notification)
def mark_read(notification_id: UUID, user: User) -> Notification:
    if get_settings().use_in_memory_store:
        raise HTTPException(status_code=404, detail="Notification not found")
    with get_session_factory()() as session, session.begin():
        row = session.execute(
            text(
                """
                UPDATE notifications SET read_at = COALESCE(read_at, NOW())
                WHERE id = :id AND user_id = :user_id
                RETURNING id, incident_id, title, body, severity, read_at, created_at
                """
            ),
            {"id": notification_id, "user_id": user.id},
        ).one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Notification not found")
    return Notification.model_validate(dict(row._mapping))
