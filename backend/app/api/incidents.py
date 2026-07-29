from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core.security import CurrentUser, get_current_user
from app.models.incident import (
    CorroborateRequest,
    FlagRequest,
    Incident,
    IncidentCreate,
    IncidentList,
    IncidentStatus,
    Location,
)
from app.services.incident_service import IncidentService, get_incident_service

router = APIRouter(prefix="/incidents", tags=["incidents"])
Service = Annotated[IncidentService, Depends(get_incident_service)]
User = Annotated[CurrentUser, Depends(get_current_user)]


@router.post("", response_model=Incident, status_code=status.HTTP_201_CREATED)
def create_incident(
    payload: IncidentCreate,
    service: Service,
    user: User,
) -> Incident:
    return service.create(payload, reporter_id=user.id)


@router.get("", response_model=IncidentList)
def list_incidents(
    service: Service,
    lat: float | None = Query(default=None, ge=-90, le=90),
    lng: float | None = Query(default=None, ge=-180, le=180),
    radius: float = Query(default=5.0, gt=0, le=50),
    type: str | None = None,
    status: IncidentStatus | None = None,
) -> IncidentList:
    if (lat is None) != (lng is None):
        raise HTTPException(status_code=400, detail="lat and lng must be provided together")
    center = Location(lat=lat, lng=lng) if lat is not None and lng is not None else None
    items = service.list(
        center=center,
        radius_km=radius,
        type_filter=type,
        status=status,
    )
    return IncidentList(items=items, total=len(items))


@router.get("/{incident_id}", response_model=Incident)
def get_incident(incident_id: UUID, service: Service) -> Incident:
    incident = service.get(incident_id)
    if not incident:
        raise HTTPException(status_code=404, detail="Incident not found")
    return incident


@router.post("/{incident_id}/corroborate", response_model=Incident)
def corroborate(
    incident_id: UUID,
    payload: CorroborateRequest,
    service: Service,
    user: User,
) -> Incident:
    try:
        return service.corroborate(incident_id, user.id, payload)
    except KeyError:
        raise HTTPException(status_code=404, detail="Incident not found") from None
    except ValueError as error:
        raise HTTPException(status_code=403, detail=str(error)) from None


@router.post("/{incident_id}/flag", response_model=Incident)
def flag(
    incident_id: UUID,
    payload: FlagRequest,
    service: Service,
    user: User,
) -> Incident:
    try:
        return service.flag(incident_id, user.id, payload)
    except KeyError:
        raise HTTPException(status_code=404, detail="Incident not found") from None
