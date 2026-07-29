from datetime import datetime, timezone
from enum import Enum
from uuid import UUID, uuid4

from pydantic import BaseModel, ConfigDict, Field


class IncidentType(str, Enum):
    kidnapping = "kidnapping"
    armed_robbery = "armed_robbery"
    roadblock = "roadblock"
    cult_clash = "cult_clash"
    banditry = "banditry"
    fire_outbreak = "fire_outbreak"
    suspicious_activity = "suspicious_activity"
    other = "other"


class IncidentStatus(str, Enum):
    unconfirmed = "unconfirmed"
    corroborated = "corroborated"
    confirmed = "confirmed"
    resolved = "resolved"
    false_report = "false_report"


class Severity(str, Enum):
    low = "low"
    medium = "medium"
    high = "high"
    critical = "critical"


class Location(BaseModel):
    lat: float = Field(ge=-90, le=90)
    lng: float = Field(ge=-180, le=180)


class IncidentCreate(BaseModel):
    type: IncidentType
    description: str | None = Field(default=None, max_length=2000)
    location: Location
    location_name: str | None = Field(default=None, max_length=255)
    lga: str | None = None
    ward: str | None = None
    severity: Severity = Severity.medium
    is_anonymous: bool = False
    media_urls: list[str] = Field(default_factory=list)


class Incident(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID = Field(default_factory=uuid4)
    reporter_id: UUID | None = None
    type: IncidentType
    description: str | None = None
    location: Location
    location_name: str | None = None
    lga: str | None = None
    ward: str | None = None
    status: IncidentStatus = IncidentStatus.unconfirmed
    severity: Severity = Severity.medium
    is_anonymous: bool = False
    media_urls: list[str] = Field(default_factory=list)
    corroboration_count: int = 0
    confirmed_by: UUID | None = None
    flag_count: int = 0
    is_hidden: bool = False
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    distance_km: float | None = None


class CorroborateRequest(BaseModel):
    location: Location


class FlagRequest(BaseModel):
    reason: str = Field(pattern="^(false_report|duplicate|spam|inappropriate)$")
    notes: str | None = Field(default=None, max_length=500)


class IncidentList(BaseModel):
    items: list[Incident]
    total: int
