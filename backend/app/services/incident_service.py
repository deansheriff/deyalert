from math import asin, cos, radians, sin, sqrt
from uuid import UUID

from app.core.config import get_settings
from app.models.incident import CorroborateRequest, FlagRequest, Incident, IncidentCreate, IncidentStatus, Location


def distance_km(a: Location, b: Location) -> float:
    """Return great-circle distance for the MVP proximity filter."""
    earth_radius_km = 6371.0
    d_lat = radians(b.lat - a.lat)
    d_lng = radians(b.lng - a.lng)
    lat_a, lat_b = radians(a.lat), radians(b.lat)
    value = sin(d_lat / 2) ** 2 + cos(lat_a) * cos(lat_b) * sin(d_lng / 2) ** 2
    return earth_radius_km * 2 * asin(sqrt(value))


class IncidentService:
    def __init__(self) -> None:
        self._incidents: dict[UUID, Incident] = {}
        self._corroborators: dict[UUID, set[UUID]] = {}
        self._flaggers: dict[UUID, set[UUID]] = {}

    def create(self, payload: IncidentCreate, reporter_id: UUID | None = None) -> Incident:
        incident = Incident(**payload.model_dump(), reporter_id=reporter_id)
        self._incidents[incident.id] = incident
        return incident

    def list(self, center: Location | None = None, radius_km: float = 5.0, type_filter: str | None = None, status: IncidentStatus | None = None) -> list[Incident]:
        results = []
        for incident in self._incidents.values():
            if incident.is_hidden or incident.status == IncidentStatus.false_report:
                continue
            if type_filter and incident.type.value != type_filter:
                continue
            if status and incident.status != status:
                continue
            if center and distance_km(center, incident.location) > radius_km:
                continue
            results.append(incident)
        return sorted(results, key=lambda item: item.created_at, reverse=True)

    def get(self, incident_id: UUID) -> Incident | None:
        return self._incidents.get(incident_id)

    def corroborate(self, incident_id: UUID, payload: CorroborateRequest) -> Incident:
        incident = self._require(incident_id)
        corroborators = self._corroborators.setdefault(incident_id, set())
        corroborators.add(payload.user_id)
        incident.corroboration_count = len(corroborators)
        if incident.corroboration_count >= get_settings().corroboration_threshold and incident.status == IncidentStatus.unconfirmed:
            incident.status = IncidentStatus.corroborated
        return incident

    def flag(self, incident_id: UUID, payload: FlagRequest) -> Incident:
        incident = self._require(incident_id)
        flaggers = self._flaggers.setdefault(incident_id, set())
        flaggers.add(payload.user_id)
        incident.flag_count = len(flaggers)
        if incident.flag_count >= get_settings().flag_hide_threshold:
            incident.is_hidden = True
        return incident

    def _require(self, incident_id: UUID) -> Incident:
        incident = self.get(incident_id)
        if not incident:
            raise KeyError(str(incident_id))
        return incident


incident_service = IncidentService()
