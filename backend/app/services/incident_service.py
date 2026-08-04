from __future__ import annotations

from math import asin, cos, radians, sin, sqrt
from typing import Protocol
from uuid import UUID, uuid4

from sqlalchemy import text

from app.core.config import get_settings
from app.core.database import get_session_factory
from app.models.incident import (
    CorroborateRequest,
    FlagRequest,
    Incident,
    IncidentCreate,
    IncidentStatus,
    Location,
)


def distance_km(a: Location, b: Location) -> float:
    earth_radius_km = 6371.0
    d_lat = radians(b.lat - a.lat)
    d_lng = radians(b.lng - a.lng)
    lat_a, lat_b = radians(a.lat), radians(b.lat)
    value = sin(d_lat / 2) ** 2 + cos(lat_a) * cos(lat_b) * sin(d_lng / 2) ** 2
    return earth_radius_km * 2 * asin(sqrt(value))


class IncidentService(Protocol):
    def create(self, payload: IncidentCreate, reporter_id: UUID) -> Incident: ...

    def list(
        self,
        center: Location | None = None,
        radius_km: float = 5.0,
        type_filter: str | None = None,
        status: IncidentStatus | None = None,
    ) -> list[Incident]: ...

    def get(self, incident_id: UUID) -> Incident | None: ...

    def corroborate(
        self,
        incident_id: UUID,
        user_id: UUID,
        payload: CorroborateRequest,
    ) -> Incident: ...

    def flag(
        self,
        incident_id: UUID,
        user_id: UUID,
        payload: FlagRequest,
    ) -> Incident: ...

    def flagged(self, limit: int = 100) -> list[Incident]: ...

    def verify(self, incident_id: UUID, actor_id: UUID) -> Incident: ...

    def moderate(
        self, incident_id: UUID, status: IncidentStatus, actor_id: UUID
    ) -> Incident: ...


class InMemoryIncidentService:
    def __init__(self) -> None:
        self._incidents: dict[UUID, Incident] = {}
        self._corroborators: dict[UUID, set[UUID]] = {}
        self._flaggers: dict[UUID, set[UUID]] = {}

    def create(self, payload: IncidentCreate, reporter_id: UUID) -> Incident:
        for existing in self._incidents.values():
            if (
                payload.client_report_id is not None
                and
                existing.reporter_id == reporter_id
                and existing.client_report_id == payload.client_report_id
            ):
                return existing
        incident = Incident(**payload.model_dump(), reporter_id=reporter_id)
        self._incidents[incident.id] = incident
        return incident

    def list(
        self,
        center: Location | None = None,
        radius_km: float = 5.0,
        type_filter: str | None = None,
        status: IncidentStatus | None = None,
    ) -> list[Incident]:
        results = []
        for incident in self._incidents.values():
            if incident.is_hidden or incident.status == IncidentStatus.false_report:
                continue
            if type_filter and incident.type.value != type_filter:
                continue
            if status and incident.status != status:
                continue
            if center:
                distance = distance_km(center, incident.location)
                if distance > radius_km:
                    continue
                incident = incident.model_copy(update={"distance_km": distance})
            results.append(incident)
        return sorted(results, key=lambda item: item.created_at, reverse=True)

    def get(self, incident_id: UUID) -> Incident | None:
        return self._incidents.get(incident_id)

    def corroborate(
        self,
        incident_id: UUID,
        user_id: UUID,
        payload: CorroborateRequest,
    ) -> Incident:
        incident = self._require(incident_id)
        if distance_km(payload.location, incident.location) > get_settings().corroboration_radius_km:
            raise ValueError("User is outside the corroboration radius")
        corroborators = self._corroborators.setdefault(incident_id, set())
        corroborators.add(user_id)
        incident.corroboration_count = len(corroborators)
        if (
            incident.corroboration_count >= get_settings().corroboration_threshold
            and incident.status == IncidentStatus.unconfirmed
        ):
            incident.status = IncidentStatus.corroborated
        return incident

    def flag(
        self,
        incident_id: UUID,
        user_id: UUID,
        payload: FlagRequest,
    ) -> Incident:
        incident = self._require(incident_id)
        flaggers = self._flaggers.setdefault(incident_id, set())
        flaggers.add(user_id)
        incident.flag_count = len(flaggers)
        if incident.flag_count >= get_settings().flag_hide_threshold:
            incident.is_hidden = True
        return incident

    def flagged(self, limit: int = 100) -> list[Incident]:
        return sorted(
            (item for item in self._incidents.values() if item.flag_count > 0),
            key=lambda item: item.flag_count,
            reverse=True,
        )[:limit]

    def verify(self, incident_id: UUID, actor_id: UUID) -> Incident:
        incident = self._require(incident_id)
        incident.status = IncidentStatus.confirmed
        incident.confirmed_by = actor_id
        return incident

    def moderate(
        self, incident_id: UUID, status: IncidentStatus, actor_id: UUID
    ) -> Incident:
        incident = self._require(incident_id)
        incident.status = status
        incident.is_hidden = status == IncidentStatus.false_report
        if status == IncidentStatus.confirmed:
            incident.confirmed_by = actor_id
        return incident

    def _require(self, incident_id: UUID) -> Incident:
        incident = self.get(incident_id)
        if not incident:
            raise KeyError(str(incident_id))
        return incident


_SELECT_COLUMNS = """
    id, client_report_id, reporter_id, type, description, location_name, lga, ward, status,
    severity, is_anonymous, media_urls, corroboration_count, confirmed_by,
    flag_count, is_hidden, created_at, updated_at,
    ST_Y(location::geometry) AS lat,
    ST_X(location::geometry) AS lng
"""


def _row_to_incident(row: object) -> Incident:
    values = dict(row._mapping)  # type: ignore[attr-defined]
    values["location"] = {
        "lat": values.pop("lat"),
        "lng": values.pop("lng"),
    }
    values["media_urls"] = values.get("media_urls") or []
    return Incident.model_validate(values)


class DatabaseIncidentService:
    def create(self, payload: IncidentCreate, reporter_id: UUID) -> Incident:
        incident_id = uuid4()
        statement = text(
            f"""
            INSERT INTO incidents (
                id, client_report_id, reporter_id, type, description, location, location_name,
                lga, ward, severity, is_anonymous, media_urls
            ) VALUES (
                :id, :client_report_id, :reporter_id, :type, :description,
                ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography,
                :location_name, :lga, :ward, :severity, :is_anonymous, :media_urls
            )
            ON CONFLICT (reporter_id, client_report_id)
              WHERE client_report_id IS NOT NULL
            DO UPDATE SET client_report_id = EXCLUDED.client_report_id
            RETURNING {_SELECT_COLUMNS}
            """
        )
        values = payload.model_dump(mode="json")
        location = values.pop("location")
        values.update(
            {
                "id": incident_id,
                "reporter_id": reporter_id,
                "lat": location["lat"],
                "lng": location["lng"],
            }
        )
        with get_session_factory()() as session, session.begin():
            row = session.execute(statement, values).one()
            return _row_to_incident(row)

    def list(
        self,
        center: Location | None = None,
        radius_km: float = 5.0,
        type_filter: str | None = None,
        status: IncidentStatus | None = None,
    ) -> list[Incident]:
        clauses = ["is_hidden = false", "status != 'false_report'"]
        params: dict[str, object] = {}
        distance_column = ""
        if center:
            clauses.append(
                "ST_DWithin(location, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography, :radius_m)"
            )
            params.update(
                {
                    "lat": center.lat,
                    "lng": center.lng,
                    "radius_m": radius_km * 1000,
                }
            )
            distance_column = (
                ", ST_Distance(location, "
                "ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography) / 1000 "
                "AS distance_km"
            )
        if type_filter:
            clauses.append("type = :type_filter")
            params["type_filter"] = type_filter
        if status:
            clauses.append("status = :status")
            params["status"] = status.value
        statement = text(
            f"""
            SELECT {_SELECT_COLUMNS} {distance_column}
            FROM incidents
            WHERE {" AND ".join(clauses)}
            ORDER BY created_at DESC
            LIMIT 200
            """
        )
        with get_session_factory()() as session:
            rows = session.execute(statement, params).all()
            return [
                _row_to_incident(row).model_copy(
                    update={
                        "distance_km": getattr(row, "distance_km", None),
                    }
                )
                for row in rows
            ]

    def get(self, incident_id: UUID) -> Incident | None:
        statement = text(
            f"SELECT {_SELECT_COLUMNS} FROM incidents WHERE id = :incident_id"
        )
        with get_session_factory()() as session:
            row = session.execute(statement, {"incident_id": incident_id}).one_or_none()
            return _row_to_incident(row) if row else None

    def corroborate(
        self,
        incident_id: UUID,
        user_id: UUID,
        payload: CorroborateRequest,
    ) -> Incident:
        settings = get_settings()
        with get_session_factory()() as session, session.begin():
            nearby = session.execute(
                text(
                    """
                    SELECT ST_DWithin(
                        location,
                        ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography,
                        :radius_m
                    )
                    FROM incidents WHERE id = :incident_id
                    """
                ),
                {
                    "incident_id": incident_id,
                    "lat": payload.location.lat,
                    "lng": payload.location.lng,
                    "radius_m": settings.corroboration_radius_km * 1000,
                },
            ).scalar_one_or_none()
            if nearby is None:
                raise KeyError(str(incident_id))
            if not nearby:
                raise ValueError("User is outside the corroboration radius")
            session.execute(
                text(
                    """
                    INSERT INTO corroborations (incident_id, user_id, location)
                    VALUES (
                        :incident_id, :user_id,
                        ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography
                    )
                    ON CONFLICT (incident_id, user_id) DO NOTHING
                    """
                ),
                {
                    "incident_id": incident_id,
                    "user_id": user_id,
                    "lat": payload.location.lat,
                    "lng": payload.location.lng,
                },
            )
            row = session.execute(
                text(
                    f"""
                    UPDATE incidents
                    SET corroboration_count = (
                            SELECT COUNT(*) FROM corroborations
                            WHERE incident_id = :incident_id
                        ),
                        status = CASE
                            WHEN status = 'unconfirmed' AND (
                                SELECT COUNT(*) FROM corroborations
                                WHERE incident_id = :incident_id
                            ) >= :threshold THEN 'corroborated'
                            ELSE status
                        END,
                        updated_at = NOW()
                    WHERE id = :incident_id
                    RETURNING {_SELECT_COLUMNS}
                    """
                ),
                {
                    "incident_id": incident_id,
                    "threshold": settings.corroboration_threshold,
                },
            ).one()
            return _row_to_incident(row)

    def flag(
        self,
        incident_id: UUID,
        user_id: UUID,
        payload: FlagRequest,
    ) -> Incident:
        settings = get_settings()
        with get_session_factory()() as session, session.begin():
            session.execute(
                text(
                    """
                    INSERT INTO incident_flags (
                        incident_id, flagged_by, reason, notes
                    ) VALUES (:incident_id, :user_id, :reason, :notes)
                    ON CONFLICT (incident_id, flagged_by) DO NOTHING
                    """
                ),
                {
                    "incident_id": incident_id,
                    "user_id": user_id,
                    "reason": payload.reason,
                    "notes": payload.notes,
                },
            )
            row = session.execute(
                text(
                    f"""
                    UPDATE incidents
                    SET flag_count = (
                            SELECT COUNT(*) FROM incident_flags
                            WHERE incident_id = :incident_id
                        ),
                        is_hidden = (
                            SELECT COUNT(*) FROM incident_flags
                            WHERE incident_id = :incident_id
                        ) >= :threshold,
                        updated_at = NOW()
                    WHERE id = :incident_id
                    RETURNING {_SELECT_COLUMNS}
                    """
                ),
                {
                    "incident_id": incident_id,
                    "threshold": settings.flag_hide_threshold,
                },
            ).one_or_none()
            if row is None:
                raise KeyError(str(incident_id))
            return _row_to_incident(row)

    def flagged(self, limit: int = 100) -> list[Incident]:
        with get_session_factory()() as session:
            rows = session.execute(
                text(
                    f"""
                    SELECT {_SELECT_COLUMNS} FROM incidents
                    WHERE flag_count > 0 OR is_hidden = true
                    ORDER BY is_hidden DESC, flag_count DESC, updated_at DESC
                    LIMIT :limit
                    """
                ),
                {"limit": limit},
            ).all()
            return [_row_to_incident(row) for row in rows]

    def verify(self, incident_id: UUID, actor_id: UUID) -> Incident:
        with get_session_factory()() as session, session.begin():
            actor = session.execute(
                text("SELECT role FROM users WHERE id = :actor_id AND is_active = true"),
                {"actor_id": actor_id},
            ).scalar_one_or_none()
            if actor not in {"verifier", "admin"}:
                raise PermissionError("Verifier role required")
            if actor == "verifier":
                allowed = session.execute(
                    text(
                        """
                        SELECT 1 FROM verifiers verifier
                        JOIN incidents incident ON incident.id = :incident_id
                        WHERE verifier.user_id = :actor_id
                          AND verifier.is_active = true
                          AND verifier.lga = incident.lga
                          AND (verifier.ward IS NULL OR verifier.ward = incident.ward)
                        """
                    ),
                    {"actor_id": actor_id, "incident_id": incident_id},
                ).scalar_one_or_none()
                if not allowed:
                    raise PermissionError("Verifier is outside the incident area")
            row = session.execute(
                text(
                    f"""
                    UPDATE incidents SET status = 'confirmed',
                      confirmed_by = :actor_id, confirmed_at = NOW(),
                      is_hidden = false, updated_at = NOW()
                    WHERE id = :incident_id
                    RETURNING {_SELECT_COLUMNS}
                    """
                ),
                {"actor_id": actor_id, "incident_id": incident_id},
            ).one_or_none()
            if row is None:
                raise KeyError(str(incident_id))
            return _row_to_incident(row)

    def moderate(
        self, incident_id: UUID, status: IncidentStatus, actor_id: UUID
    ) -> Incident:
        with get_session_factory()() as session, session.begin():
            row = session.execute(
                text(
                    f"""
                    UPDATE incidents SET status = :status,
                      is_hidden = (:status = 'false_report'),
                      resolved_at = CASE WHEN :status = 'resolved' THEN NOW()
                                         ELSE resolved_at END,
                      confirmed_by = CASE WHEN :status = 'confirmed'
                                          THEN :actor_id ELSE confirmed_by END,
                      confirmed_at = CASE WHEN :status = 'confirmed'
                                          THEN NOW() ELSE confirmed_at END,
                      updated_at = NOW()
                    WHERE id = :incident_id
                    RETURNING {_SELECT_COLUMNS}
                    """
                ),
                {
                    "actor_id": actor_id,
                    "incident_id": incident_id,
                    "status": status.value,
                },
            ).one_or_none()
            if row is None:
                raise KeyError(str(incident_id))
            return _row_to_incident(row)


_in_memory_service = InMemoryIncidentService()
_database_service = DatabaseIncidentService()


def get_incident_service() -> IncidentService:
    if get_settings().use_in_memory_store:
        return _in_memory_service
    return _database_service
