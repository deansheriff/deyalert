from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, status

from app.models.incident import CorroborateRequest, FlagRequest, Incident, IncidentCreate, IncidentList, IncidentStatus, Location
from app.services.incident_service import incident_service

router = APIRouter(prefix="/incidents", tags=["incidents"])


@router.post("", response_model=Incident, status_code=status.HTTP_201_CREATED)
def create_incident(payload: IncidentCreate) -> Incident:
    return incident_service.create(payload)


@router.get("", response_model=IncidentList)
def list_incidents(
    lat: float | None = Query(default=None, ge=-90, le=90),
    lng: float | None = Query(default=None, ge=-180, le=180),
    radius: float = Query(default=5.0, gt=0, le=50),
    type: str | None = None,
    status: IncidentStatus | None = None,
) -> IncidentList:
    if (lat is None) != (lng is None):
        raise HTTPException(status_code=400, detail="lat and lng must be provided together")
    center = Location(lat=lat, lng=lng) if lat is not None and lng is not None else None
    items = incident_service.list(center=center, radius_km=radius, type_filter=type, status=status)
    return IncidentList(items=items, total=len(items))


@router.get("/{incident_id}", response_model=Incident)
def get_incident(incident_id: UUID) -> Incident:
    incident = incident_service.get(incident_id)
    if not incident:
        raise HTTPException(status_code=404, detail="Incident not found")
    return incident


@router.post("/{incident_id}/corroborate", response_model=Incident)
def corroborate(incident_id: UUID, payload: CorroborateRequest) -> Incident:
    try:
        return incident_service.corroborate(incident_id, payload)
    except KeyError:
        raise HTTPException(status_code=404, detail="Incident not found") from None


@router.post("/{incident_id}/flag", response_model=Incident)
def flag(incident_id: UUID, payload: FlagRequest) -> Incident:
    try:
        return incident_service.flag(incident_id, payload)
    except KeyError:
        raise HTTPException(status_code=404, detail="Incident not found") from None
