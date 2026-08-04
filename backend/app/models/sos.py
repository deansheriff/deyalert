from datetime import datetime, timezone
from uuid import UUID, uuid4

from pydantic import BaseModel, Field

from app.models.incident import Location


class TrustedContactCreate(BaseModel):
    name: str = Field(min_length=2, max_length=100)
    phone: str = Field(pattern=r"^\+[1-9]\d{7,14}$", max_length=20)
    relationship: str | None = Field(default=None, max_length=50)


class TrustedContact(TrustedContactCreate):
    id: UUID = Field(default_factory=uuid4)
    user_id: UUID


class SosCreate(BaseModel):
    client_alert_id: UUID
    location: Location


class SosAlert(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    user_id: UUID
    incident_id: UUID | None = None
    status: str = "active"
    delivered_to: int = 0
    contact_count: int = 0
    triggered_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class SosReadiness(BaseModel):
    ready: bool
    contact_count: int
    sms_provider: str
    message: str
