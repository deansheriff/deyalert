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
            email=user.email,
            phone_verified=False,
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
                id, email, phone, name, state, lga, ward, alert_radius_km,
                location_precision, phone_verified
            ) VALUES (
                :id, :email, :phone, :name, :state, :lga, :ward,
                :alert_radius_km, :location_precision, false
            )
            ON CONFLICT (id) DO UPDATE SET
                email = EXCLUDED.email,
                phone_verified = CASE
                    WHEN users.phone IS DISTINCT FROM EXCLUDED.phone THEN false
                    ELSE users.phone_verified
                END,
                phone = EXCLUDED.phone,
                name = EXCLUDED.name,
                state = EXCLUDED.state,
                lga = EXCLUDED.lga,
                ward = EXCLUDED.ward,
                alert_radius_km = EXCLUDED.alert_radius_km,
                location_precision = EXCLUDED.location_precision,
                updated_at = NOW()
            RETURNING id, email, phone, phone_verified, name, state, lga,
                      ward, alert_radius_km, location_precision, role
            """
        )
        values = payload.model_dump()
        values.update({"id": user.id, "email": user.email})
        with get_session_factory()() as session, session.begin():
            area_exists = session.execute(
                text(
                    """
                    SELECT 1 FROM lga_wards
                    WHERE LOWER(state) = LOWER(:state)
                      AND LOWER(lga) = LOWER(:lga)
                      AND LOWER(ward) = LOWER(:ward)
                    """
                ),
                values,
            ).scalar_one_or_none()
            if not area_exists:
                raise ValueError("Select a configured pilot state, LGA, and ward")
            row = session.execute(statement, values).one()
            return UserProfile.model_validate(dict(row._mapping))

    def get(self, user_id: UUID) -> UserProfile | None:
        with get_session_factory()() as session:
            row = session.execute(
                text(
                    """
                    SELECT id, email, phone, phone_verified, name, state, lga,
                           ward, alert_radius_km, location_precision, role
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
