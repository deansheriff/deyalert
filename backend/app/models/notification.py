from datetime import datetime
from uuid import UUID

from pydantic import BaseModel


class Notification(BaseModel):
    id: UUID
    incident_id: UUID | None = None
    title: str
    body: str
    severity: str
    read_at: datetime | None = None
    created_at: datetime


class NotificationList(BaseModel):
    items: list[Notification]
    total: int
    unread: int
