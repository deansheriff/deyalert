from uuid import UUID

from pydantic import BaseModel, Field


class ProfileUpdate(BaseModel):
    name: str = Field(min_length=2, max_length=100)
    phone: str | None = Field(
        default=None,
        pattern=r"^\+[1-9]\d{7,14}$",
        max_length=20,
    )
    state: str = Field(min_length=2, max_length=50)
    lga: str = Field(min_length=2, max_length=100)
    ward: str = Field(min_length=2, max_length=100)
    alert_radius_km: float = Field(default=5, ge=1, le=20)
    location_precision: str = Field(pattern="^(exact|ward|lga)$")


class UserProfile(ProfileUpdate):
    id: UUID
    email: str | None
    phone_verified: bool = False
    role: str = "member"
