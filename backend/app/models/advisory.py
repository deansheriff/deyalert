from datetime import datetime, timezone
from enum import Enum
from uuid import UUID, uuid4

from pydantic import BaseModel, Field

from app.models.incident import IncidentType, Location, Severity


class LocationConfidence(str, Enum):
    exact = "exact"
    city = "city"
    state = "state"
    unknown = "unknown"


class AdvisoryStatus(str, Enum):
    pending = "pending"
    published = "published"
    rejected = "rejected"
    expired = "expired"
    retracted = "retracted"


class AdvisorySource(BaseModel):
    source_name: str
    title: str
    url: str
    published_at: datetime


class SecurityAdvisory(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    title: str
    summary: str | None = None
    type: IncidentType
    severity: Severity = Severity.medium
    location: Location | None = None
    location_name: str | None = None
    location_confidence: LocationConfidence = LocationConfidence.unknown
    status: AdvisoryStatus = AdvisoryStatus.pending
    source_count: int = 1
    article_count: int = 1
    first_published_at: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc)
    )
    last_updated_at: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc)
    )
    expires_at: datetime
    distance_km: float | None = None
    trend_score: float = 0
    sources: list[AdvisorySource] = Field(default_factory=list)


class AdvisoryList(BaseModel):
    items: list[SecurityAdvisory]
    total: int


class AdvisoryReview(BaseModel):
    status: AdvisoryStatus


class ArticleCandidate(BaseModel):
    source_name: str
    title: str
    summary: str | None = None
    url: str
    image_url: str | None = None
    author: str | None = None
    published_at: datetime
    content_hash: str
    type: IncidentType
    severity: Severity
    location: Location | None = None
    location_name: str | None = None
    location_confidence: LocationConfidence = LocationConfidence.unknown
