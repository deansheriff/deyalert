from typing import Protocol
from uuid import UUID

from sqlalchemy import text

from app.core.config import get_settings
from app.core.database import get_session_factory
from app.core.security import CurrentUser
from app.models.user import ProfileUpdate, UserProfile


class ProfileService(Protocol):
    def upsert(self, user: CurrentUser, payload: ProfileUpdate) -> UserProfile: ...

    def get(self, user_id: UUID) -> UserProfile | None: ...


class InMemoryProfileService:
    def __init__(self) -> None:
        self._profiles: dict[UUID, UserProfile] = {}

    def upsert(self, user: CurrentUser, payload: ProfileUpdate) -> UserProfile:
        profile = UserProfile(
            id=user.id,
            phone=user.phone,
            role="member",
            **payload.model_dump(),
        )
        self._profiles[user.id] = profile
        return profile

    def get(self, user_id: UUID) -> UserProfile | None:
        return self._profiles.get(user_id)


class DatabaseProfileService:
    def upsert(self, user: CurrentUser, payload: ProfileUpdate) -> UserProfile:
        statement = text(
            """
            INSERT INTO users (
                id, phone, name, state, lga, ward, alert_radius_km,
                location_precision
            ) VALUES (
                :id, :phone, :name, :state, :lga, :ward, :alert_radius_km,
                :location_precision
            )
            ON CONFLICT (id) DO UPDATE SET
                phone = EXCLUDED.phone,
                name = EXCLUDED.name,
                state = EXCLUDED.state,
                lga = EXCLUDED.lga,
                ward = EXCLUDED.ward,
                alert_radius_km = EXCLUDED.alert_radius_km,
                location_precision = EXCLUDED.location_precision,
                updated_at = NOW()
            RETURNING id, phone, name, state, lga, ward, alert_radius_km,
                      location_precision, role
            """
        )
        values = payload.model_dump()
        values.update({"id": user.id, "phone": user.phone})
        with get_session_factory()() as session, session.begin():
            row = session.execute(statement, values).one()
            return UserProfile.model_validate(dict(row._mapping))

    def get(self, user_id: UUID) -> UserProfile | None:
        with get_session_factory()() as session:
            row = session.execute(
                text(
                    """
                    SELECT id, phone, name, state, lga, ward, alert_radius_km,
                           location_precision, role
                    FROM users WHERE id = :user_id
                    """
                ),
                {"user_id": user_id},
            ).one_or_none()
            return UserProfile.model_validate(dict(row._mapping)) if row else None


_in_memory_profiles = InMemoryProfileService()
_database_profiles = DatabaseProfileService()


def get_profile_service() -> ProfileService:
    if get_settings().use_in_memory_store:
        return _in_memory_profiles
    return _database_profiles
